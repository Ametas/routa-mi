package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
)

const serviceName = "RoutaMiHelperService" // appHelperService in lib/common/constant.dart

func main() {
	if isService, err := svc.IsWindowsService(); err == nil && isService {
		_ = svc.Run(serviceName, &service{})
		return
	}
	// The app runs "install" elevated (one UAC prompt); the uninstaller runs
	// "uninstall".
	var err error
	switch arg := strings.Join(os.Args[1:], " "); arg {
	case "install":
		err = install()
	case "uninstall":
		err = uninstall()
	default:
		err = fmt.Errorf("usage: %s install|uninstall", filepath.Base(os.Args[0]))
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func install() error {
	executable, err := installDir()
	if err != nil {
		return err
	}
	m, err := mgr.Connect()
	if err != nil {
		return err
	}
	defer m.Disconnect()
	if s, err := m.OpenService(serviceName); err == nil {
		stopService(s)
		err = s.Delete()
		s.Close()
		if err != nil {
			return err
		}
		waitDeleted(m)
	}
	// CreateService quotes the path, so a directory with spaces is safe.
	s, err := m.CreateService(serviceName, executable, mgr.Config{
		DisplayName: "RoutaMi Helper Service",
		Description: "Runs the RoutaMi core with the rights TUN mode needs.",
		StartType:   mgr.StartAutomatic,
	})
	if err != nil {
		return err
	}
	defer s.Close()
	return s.Start()
}

func uninstall() error {
	m, err := mgr.Connect()
	if err != nil {
		return err
	}
	defer m.Disconnect()
	s, err := m.OpenService(serviceName)
	if err != nil {
		return nil
	}
	defer s.Close()
	stopService(s)
	return s.Delete()
}

func stopService(s *mgr.Service) {
	status, err := s.Control(svc.Stop)
	for i := 0; err == nil && status.State != svc.Stopped && i < 50; i++ {
		time.Sleep(100 * time.Millisecond)
		status, err = s.Query()
	}
}

// waitDeleted waits until a deleted service is gone, or CreateService fails
// with ERROR_SERVICE_MARKED_FOR_DELETE.
func waitDeleted(m *mgr.Mgr) {
	for i := 0; i < 50; i++ {
		s, err := m.OpenService(serviceName)
		if err != nil {
			return
		}
		s.Close()
		time.Sleep(100 * time.Millisecond)
	}
}

// installDir returns the helper executable if it is installed under Program
// Files: a LocalSystem service must not run from a directory a user can
// write to, or whoever replaced the files next to it would run as SYSTEM.
func installDir() (string, error) {
	executable, err := os.Executable()
	if err != nil {
		return "", err
	}
	programFiles := os.Getenv("ProgramFiles")
	dir := strings.ToLower(filepath.Dir(executable)) + `\`
	if programFiles == "" || !strings.HasPrefix(dir, strings.ToLower(filepath.Clean(programFiles))+`\`) {
		return "", errors.New("TUN mode needs RoutaMi installed in Program Files")
	}
	return executable, nil
}

type service struct{}

func (*service) Execute(_ []string, requests <-chan svc.ChangeRequest, status chan<- svc.Status) (bool, uint32) {
	status <- svc.Status{State: svc.StartPending}
	h, err := newHelper()
	if err != nil {
		return true, 1
	}
	listener, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return true, 2
	}
	server := &http.Server{Handler: h.handler(), ReadHeaderTimeout: 5 * time.Second}
	go func() { _ = server.Serve(listener) }()
	status <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}
	for request := range requests {
		switch request.Cmd {
		case svc.Interrogate:
			status <- request.CurrentStatus
		case svc.Stop, svc.Shutdown:
			status <- svc.Status{State: svc.StopPending}
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			_ = server.Shutdown(ctx)
			cancel()
			h.stop()
			return false, 0
		}
	}
	return false, 0
}

func newHelper() (*helper, error) {
	executable, err := installDir()
	if err != nil {
		return nil, err
	}
	return &helper{dir: filepath.Dir(executable), callerPath: callerPath, spawn: spawn}, nil
}

type childProcess struct{ cmd *exec.Cmd }

func (p childProcess) Kill() error { return p.cmd.Process.Kill() }
func (p childProcess) Wait() error { return p.cmd.Wait() }

func spawn(path, arg string, log func(string)) (process, error) {
	cmd := exec.Command(path, arg)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: windows.CREATE_NO_WINDOW}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			log(scanner.Text())
		}
	}()
	return childProcess{cmd}, nil
}

var getExtendedTcpTable = windows.NewLazySystemDLL("iphlpapi.dll").NewProc("GetExtendedTcpTable")

// tcpRowOwnerPID is MIB_TCPROW_OWNER_PID; ports are in network byte order.
type tcpRowOwnerPID struct {
	State      uint32
	LocalAddr  uint32
	LocalPort  uint32
	RemoteAddr uint32
	RemotePort uint32
	OwningPID  uint32
}

const tcpTableOwnerPIDConnections = 4

func networkPort(port uint32) int { return int(port&0xff)<<8 | int(port>>8&0xff) }

// callerPath finds the process that owns the client end of the request's
// loopback connection and returns its executable.
func callerPath(r *http.Request) (string, error) {
	_, portText, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return "", err
	}
	clientPort, err := strconv.Atoi(portText)
	if err != nil {
		return "", err
	}
	_, serverPortText, _ := net.SplitHostPort(listenAddr)
	serverPort, _ := strconv.Atoi(serverPortText)

	var size uint32
	_, _, _ = getExtendedTcpTable.Call(0, uintptr(unsafe.Pointer(&size)), 0, windows.AF_INET, tcpTableOwnerPIDConnections, 0)
	if size == 0 {
		return "", errors.New("empty TCP table")
	}
	buffer := make([]byte, size)
	result, _, _ := getExtendedTcpTable.Call(uintptr(unsafe.Pointer(&buffer[0])), uintptr(unsafe.Pointer(&size)), 0, windows.AF_INET, tcpTableOwnerPIDConnections, 0)
	if result != 0 {
		return "", fmt.Errorf("GetExtendedTcpTable: %d", result)
	}
	count := *(*uint32)(unsafe.Pointer(&buffer[0]))
	rows := unsafe.Slice((*tcpRowOwnerPID)(unsafe.Pointer(&buffer[4])), count)
	for _, row := range rows {
		if networkPort(row.LocalPort) == clientPort && networkPort(row.RemotePort) == serverPort {
			return processPath(row.OwningPID)
		}
	}
	return "", errors.New("no TCP connection for the request")
}

func processPath(pid uint32) (string, error) {
	handle, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, pid)
	if err != nil {
		return "", err
	}
	defer windows.CloseHandle(handle)
	buffer := make([]uint16, windows.MAX_LONG_PATH)
	size := uint32(len(buffer))
	if err := windows.QueryFullProcessImageName(handle, 0, &buffer[0], &size); err != nil {
		return "", err
	}
	return windows.UTF16ToString(buffer[:size]), nil
}
