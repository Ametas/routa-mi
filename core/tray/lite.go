package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"time"
)

// snapshot is what the app hands the tray on its stdin when it enters lite
// mode (lib/common/lite.dart).
type snapshot struct {
	State  string `json:"state"`  // lite.json, how the app finds the tray
	App    string `json:"app"`    // RoutaMi.exe, started by "Open"
	Core   string `json:"core"`   // RoutaMiCore.exe
	Helper bool   `json:"helper"` // the core runs under RoutaMiHelperService
	Tun    bool   `json:"tun"`
	// SystemProxy is applied while the core runs, as the app does.
	SystemProxy struct {
		Enable bool     `json:"enable"`
		Port   int      `json:"port"`
		Bypass []string `json:"bypass"`
	} `json:"systemProxy"`
	Icons struct {
		Off string `json:"off"`
		On  string `json:"on"`
		Tun string `json:"tun"`
	} `json:"icons"`
	Labels struct {
		Title   string `json:"title"`
		Open    string `json:"open"`
		Start   string `json:"start"`
		Stop    string `json:"stop"`
		Restart string `json:"restart"`
		Exit    string `json:"exit"`
	} `json:"labels"`
}

// restoreState mirrors core/handover.go.
type restoreState struct {
	Init       string `json:"init"`
	Engine     string `json:"engine"`
	Setup      string `json:"setup,omitempty"`
	Update     string `json:"update,omitempty"`
	XraySetup  string `json:"xraySetup,omitempty"`
	XraySelect string `json:"xraySelect,omitempty"`
	Running    bool   `json:"running"`
	Pid        int    `json:"pid"`
}

// liteState is lite.json: where the app reaches a running tray.
type liteState struct {
	Pid   int    `json:"pid"`
	Port  int    `json:"port"`
	Token string `json:"token"`
}

// platform is what differs on Windows (platform_windows.go) and in tests.
type platform interface {
	runUI(t *liteTray) // blocks until quitUI
	quitUI()
	updateUI(running bool)
	setSystemProxy(enable bool, port int, bypass []string) error
	// startCore runs the core with the IPC address, through the helper
	// service when helper is set.
	startCore(path, arg string, helper bool) error
	stopHelperCore() error
	waitExit(pid int, timeout time.Duration)
	openApp(path string) error
}

const (
	callTimeout    = 10 * time.Second
	connectTimeout = 20 * time.Second
)

// liteTray keeps the core running after the app has exited: it owns the
// core's IPC, the system proxy and the tray icon until the app takes the
// core back (POST /attach) or the user exits.
type liteTray struct {
	snap snapshot
	plat platform

	mu       sync.Mutex // one operation at a time
	link     *coreLink
	restore  restoreState
	running  bool
	proxyOn  bool
	quitOnce sync.Once
	done     chan struct{}
	token    string
	server   *http.Server
}

func newLiteTray(snap snapshot, plat platform) *liteTray {
	return &liteTray{snap: snap, plat: plat, done: make(chan struct{}), token: randomToken()}
}

// adopt makes link the tray's core and reads its state. Called with mu held.
func (t *liteTray) adopt(link *coreLink) error {
	raw, err := link.call("getRestoreState", nil, callTimeout)
	if err != nil {
		return err
	}
	var restore restoreState
	if err := json.Unmarshal(raw, &restore); err != nil {
		return err
	}
	t.link = link
	t.restore = restore
	t.running = restore.Running
	// The app had the system proxy set while it ran.
	t.proxyOn = t.running && t.snap.SystemProxy.Enable
	go t.watch(link)
	t.plat.updateUI(t.running)
	return nil
}

// watch notices a core that exits on its own.
func (t *liteTray) watch(link *coreLink) {
	<-link.closed
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.link != link {
		return // replaced on purpose
	}
	log.Printf("the core exited")
	t.link = nil
	t.running = false
	t.applyProxy()
	t.plat.updateUI(false)
}

// applyProxy makes the system proxy follow the running state. mu held.
func (t *liteTray) applyProxy() {
	want := t.running && t.snap.SystemProxy.Enable
	if want == t.proxyOn {
		return
	}
	p := t.snap.SystemProxy
	if err := t.plat.setSystemProxy(want, p.Port, p.Bypass); err != nil {
		log.Printf("system proxy: %v", err)
		return
	}
	t.proxyOn = want
}

// toggle starts or stops the listeners; a gone core is restarted.
func (t *liteTray) toggle() error {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.link == nil || !t.link.alive() {
		t.restore.Running = true
		return t.restartLocked()
	}
	method := "startListener"
	if t.running {
		method = "stopListener"
	}
	if _, err := t.link.call(method, nil, callTimeout); err != nil {
		return err
	}
	t.running = !t.running
	t.restore.Running = t.running
	t.applyProxy()
	t.plat.updateUI(t.running)
	return nil
}

func (t *liteTray) restart() error {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.restartLocked()
}

// restartLocked replaces the core process with a new one in the same state.
func (t *liteTray) restartLocked() error {
	if t.link != nil && t.link.alive() {
		raw, err := t.link.call("getRestoreState", nil, 3*time.Second)
		var fresh restoreState
		if err == nil && json.Unmarshal(raw, &fresh) == nil {
			t.restore = fresh
		}
	}
	t.stopCoreLocked()
	if t.restore.Init == "" {
		return errors.New("no core state to restart from")
	}
	ln, err := listenCore()
	if err != nil {
		return err
	}
	if err := t.plat.startCore(t.snap.Core, ln.address(), t.snap.Helper); err != nil {
		ln.close()
		return err
	}
	link, err := ln.accept(connectTimeout)
	if err != nil {
		return err
	}
	if err := replay(link, t.restore); err != nil {
		link.close()
		return err
	}
	return t.adopt(link)
}

// replay brings a fresh core to the state of the one it replaces.
func replay(link *coreLink, s restoreState) error {
	raw, err := link.call("initClash", s.Init, callTimeout)
	if err != nil {
		return err
	}
	if ok, _ := strconv.ParseBool(string(raw)); !ok {
		return errors.New("initClash failed")
	}
	if s.Engine == "xray" {
		if err := link.callText("xraySetup", s.XraySetup, callTimeout); err != nil {
			log.Printf("%v", err)
		}
		if s.XraySelect != "" {
			if err := link.callText("xraySelect", s.XraySelect, callTimeout); err != nil {
				log.Printf("%v", err)
			}
		}
	} else if s.Setup != "" {
		// A profile that failed to apply failed for the old core too: the
		// new one is in the same state, so the restart goes on.
		if err := link.callText("setupConfig", s.Setup, time.Minute); err != nil {
			log.Printf("%v", err)
		}
		if s.Update != "" {
			if err := link.callText("updateConfig", s.Update, callTimeout); err != nil {
				log.Printf("%v", err)
			}
		}
	}
	if s.Running {
		if _, err := link.call("startListener", nil, callTimeout); err != nil {
			return err
		}
	}
	return nil
}

// stopCoreLocked ends the current core: it exits when its IPC drops.
func (t *liteTray) stopCoreLocked() {
	link := t.link
	t.link = nil
	if link != nil {
		link.close()
	}
	if t.snap.Helper {
		if err := t.plat.stopHelperCore(); err != nil {
			log.Printf("helper stop: %v", err)
		}
	}
	if t.restore.Pid != 0 {
		t.plat.waitExit(t.restore.Pid, 5*time.Second)
	}
}

// attach hands the core to the app listening at addr and ends the tray.
func (t *liteTray) attach(addr string) (map[string]any, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.link == nil || !t.link.alive() {
		return nil, errCoreGone
	}
	if err := t.link.callText("handover", addr, callTimeout); err != nil {
		return nil, err
	}
	// The core now talks to the app; this link closes by itself.
	t.link = nil
	// The app sets the system proxy again from its own settings.
	return map[string]any{"running": t.running, "helper": t.snap.Helper}, nil
}

// exit stops the core and the system proxy and ends the tray.
func (t *liteTray) exit() {
	t.mu.Lock()
	t.running = false
	t.applyProxy()
	t.stopCoreLocked()
	t.mu.Unlock()
	t.quit()
}

func (t *liteTray) quit() {
	t.quitOnce.Do(func() {
		_ = os.Remove(t.snap.State)
		close(t.done)
		t.plat.quitUI()
	})
}

func (t *liteTray) openApp() {
	if err := t.plat.openApp(t.snap.App); err != nil {
		log.Printf("open app: %v", err)
	}
}

// serve starts the control API and writes lite.json.
func (t *liteTray) serve() error {
	ln, err := net.ListenTCP("tcp", &net.TCPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		return err
	}
	t.server = &http.Server{Handler: t.handler(), ReadHeaderTimeout: 5 * time.Second}
	go func() { _ = t.server.Serve(ln) }()
	state := liteState{Pid: os.Getpid(), Port: ln.Addr().(*net.TCPAddr).Port, Token: t.token}
	return writeJSONFile(t.snap.State, state)
}

func writeJSONFile(path string, value any) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// handler is the control API on 127.0.0.1 for the app (attach) and for
// tests (the rest mirror the menu). Every call carries lite.json's token.
func (t *liteTray) handler() http.Handler {
	mux := http.NewServeMux()
	reply := func(w http.ResponseWriter, value any, err error) {
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(value)
	}
	mux.HandleFunc("GET /status", func(w http.ResponseWriter, r *http.Request) {
		t.mu.Lock()
		status := map[string]any{"running": t.running, "connected": t.link != nil && t.link.alive()}
		t.mu.Unlock()
		reply(w, status, nil)
	})
	mux.HandleFunc("POST /attach", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Address string `json:"address"`
		}
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&body); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		result, err := t.attach(body.Address)
		reply(w, result, err)
		if err == nil {
			go t.quit()
		}
	})
	mux.HandleFunc("POST /toggle", func(w http.ResponseWriter, r *http.Request) {
		reply(w, map[string]any{}, t.toggle())
	})
	mux.HandleFunc("POST /restart", func(w http.ResponseWriter, r *http.Request) {
		reply(w, map[string]any{}, t.restart())
	})
	mux.HandleFunc("POST /exit", func(w http.ResponseWriter, r *http.Request) {
		reply(w, map[string]any{}, nil)
		go t.exit()
	})
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer "+t.token {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		mux.ServeHTTP(w, r)
	})
}

// run is the tray's life: take the core from the app, then serve.
// out receives one JSON line with the address the app hands the core to.
func run(snap snapshot, plat platform, out func(string)) error {
	ln, err := listenCore()
	if err != nil {
		return err
	}
	line, _ := json.Marshal(map[string]string{"core": ln.address()})
	out(string(line))
	link, err := ln.accept(connectTimeout)
	if err != nil {
		return err
	}
	t := newLiteTray(snap, plat)
	t.mu.Lock()
	err = t.adopt(link)
	t.mu.Unlock()
	if err != nil {
		link.close()
		return fmt.Errorf("adopt the core: %w", err)
	}
	if err := t.serve(); err != nil {
		t.exit()
		return err
	}
	log.Printf("lite mode: core pid %d, running %v", t.restore.Pid, t.running)
	plat.runUI(t)
	if t.server != nil {
		_ = t.server.Close()
	}
	return nil
}
