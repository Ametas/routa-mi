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
)

const serviceName = "RoutaMiHelperService" // appHelperService in lib/common/constant.dart

func main() {
	isService, err := svc.IsWindowsService()
	if err != nil || !isService {
		fmt.Fprintln(os.Stderr, "RoutaMiHelperService runs as a Windows service; the app registers it.")
		os.Exit(1)
	}
	_ = svc.Run(serviceName, &service{})
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
	executable, err := os.Executable()
	if err != nil {
		return nil, err
	}
	dir := filepath.Dir(executable)
	// A LocalSystem service must not run from a directory a user can write
	// to: whoever could replace the files next to it would run as SYSTEM.
	programFiles := os.Getenv("ProgramFiles")
	if programFiles == "" || !strings.HasPrefix(strings.ToLower(dir)+`\`, strings.ToLower(filepath.Clean(programFiles))+`\`) {
		return nil, errors.New("the helper only runs from Program Files")
	}
	return &helper{dir: dir, callerPath: callerPath, spawn: spawn}, nil
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
