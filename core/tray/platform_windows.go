//go:build windows

package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os/exec"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"fyne.io/systray"
	"golang.org/x/sys/windows"
)

// helperURL is RoutaMiHelperService (core/helper, helperPort in
// lib/common/constant.dart). It accepts RoutaMiTray.exe next to it.
const helperURL = "http://127.0.0.1:47990"

type winPlatform struct {
	tray   *liteTray
	toggle *systray.MenuItem
}

func newPlatform() platform { return &winPlatform{} }

func (p *winPlatform) runUI(t *liteTray) {
	p.tray = t
	systray.Run(p.onReady, nil)
}

func (p *winPlatform) onReady() {
	t := p.tray
	l := t.snap.Labels
	systray.SetTooltip(l.Title)
	systray.SetOnTapped(t.openApp) // left click; right click shows the menu
	open := systray.AddMenuItem(l.Open, "")
	systray.AddSeparator()
	p.toggle = systray.AddMenuItem(l.Start, "")
	restart := systray.AddMenuItem(l.Restart, "")
	systray.AddSeparator()
	exit := systray.AddMenuItem(l.Exit, "")
	t.mu.Lock()
	p.updateUI(t.running)
	t.mu.Unlock()
	go func() {
		for {
			var err error
			select {
			case <-open.ClickedCh:
				t.openApp()
			case <-p.toggle.ClickedCh:
				err = t.toggle()
			case <-restart.ClickedCh:
				err = t.restart()
			case <-exit.ClickedCh:
				t.exit()
				return
			case <-t.done:
				return
			}
			if err != nil {
				log.Printf("%v", err)
			}
		}
	}()
}

func (p *winPlatform) quitUI() { systray.Quit() }

func (p *winPlatform) updateUI(running bool) {
	if p.toggle == nil {
		return
	}
	s := p.tray.snap
	icon := s.Icons.Off
	p.toggle.SetTitle(s.Labels.Start)
	if running {
		icon = s.Icons.On
		if s.Tun {
			icon = s.Icons.Tun
		}
		p.toggle.SetTitle(s.Labels.Stop)
	}
	if err := systray.SetIconFromFilePath(icon); err != nil {
		log.Printf("tray icon: %v", err)
	}
}

func (p *winPlatform) startCore(path, arg string, helper bool) error {
	if helper {
		body, _ := json.Marshal(map[string]string{"path": path, "arg": arg})
		return helperCall("/start", body)
	}
	cmd := exec.Command(path, arg)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: windows.CREATE_NO_WINDOW}
	if err := cmd.Start(); err != nil {
		return err
	}
	go func() { _ = cmd.Wait() }()
	return nil
}

func (p *winPlatform) stopHelperCore() error { return helperCall("/stop", nil) }

// helperCall posts to the helper; a non-empty body is its error.
func helperCall(path string, body []byte) error {
	client := http.Client{Timeout: 15 * time.Second}
	resp, err := client.Post(helperURL+path, "application/json", bytes.NewReader(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	text, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<10))
	if resp.StatusCode != http.StatusOK || len(bytes.TrimSpace(text)) > 0 {
		return fmt.Errorf("helper %s: %s %s", path, resp.Status, strings.TrimSpace(string(text)))
	}
	return nil
}

func (p *winPlatform) waitExit(pid int, timeout time.Duration) {
	h, err := windows.OpenProcess(windows.SYNCHRONIZE|windows.PROCESS_TERMINATE, false, uint32(pid))
	if err != nil {
		return // already gone, or the helper's (LocalSystem) core
	}
	defer windows.CloseHandle(h)
	event, _ := windows.WaitForSingleObject(h, uint32(timeout.Milliseconds()))
	if event == uint32(windows.WAIT_TIMEOUT) {
		_ = windows.TerminateProcess(h, 1)
		_, _ = windows.WaitForSingleObject(h, 2000)
	}
}

func (p *winPlatform) openApp(path string) error {
	cmd := exec.Command(path)
	return cmd.Start()
}

// WinINet, as plugins/proxy does for the app (LAN settings only: lite mode
// does not walk the dial-up entries).
var (
	wininet              = windows.NewLazySystemDLL("wininet.dll")
	internetSetOptionW   = wininet.NewProc("InternetSetOptionW")
	errInternetSetOption = errors.New("InternetSetOptionW failed")
)

const (
	optionPerConnection   = 75
	optionSettingsChanged = 39
	optionRefresh         = 37
	perConnFlags          = 1
	perConnProxyServer    = 2
	perConnProxyBypass    = 3
	proxyTypeDirect       = 1
	proxyTypeProxy        = 2
)

type perConnOption struct {
	option uint32
	value  uintptr // DWORD or LPWSTR (the union's FILETIME is not used)
}

type perConnOptionList struct {
	size        uint32
	connection  *uint16
	optionCount uint32
	optionError uint32
	options     *perConnOption
}

func setOption(option uintptr, buffer unsafe.Pointer, size uintptr) error {
	ok, _, _ := internetSetOptionW.Call(0, option, uintptr(buffer), size)
	if ok == 0 {
		return errInternetSetOption
	}
	return nil
}

func (p *winPlatform) setSystemProxy(enable bool, port int, bypass []string) error {
	options := []perConnOption{{option: perConnFlags, value: proxyTypeDirect}}
	if enable {
		server, _ := windows.UTF16PtrFromString(fmt.Sprintf("127.0.0.1:%d", port))
		list, _ := windows.UTF16PtrFromString(strings.Join(bypass, ";"))
		options = []perConnOption{
			{option: perConnFlags, value: proxyTypeDirect | proxyTypeProxy},
			{option: perConnProxyServer, value: uintptr(unsafe.Pointer(server))},
			{option: perConnProxyBypass, value: uintptr(unsafe.Pointer(list))},
		}
	}
	list := perConnOptionList{
		size:        uint32(unsafe.Sizeof(perConnOptionList{})),
		optionCount: uint32(len(options)),
		options:     &options[0],
	}
	if err := setOption(optionPerConnection, unsafe.Pointer(&list), unsafe.Sizeof(list)); err != nil {
		return err
	}
	_ = setOption(optionSettingsChanged, nil, 0)
	return setOption(optionRefresh, nil, 0)
}
