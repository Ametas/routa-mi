package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// fakeSetupError is what setupConfig answers ("" is success).
var fakeSetupError = ""

// fakeCore speaks the core's IPC like core/server.go and core/handover.go.
type fakeCore struct {
	mu      sync.Mutex
	conn    net.Conn
	state   restoreState
	calls   []string
	stopped chan struct{}
}

func dialFake(addr string) (net.Conn, error) {
	rest := strings.TrimPrefix(addr, "tcp:")
	port, token, _ := strings.Cut(rest, ":")
	conn, err := net.Dial("tcp", "127.0.0.1:"+port)
	if err != nil {
		return nil, err
	}
	return conn, writeFrame(conn, []byte(token))
}

func startFakeCore(t *testing.T, addr string, state restoreState) *fakeCore {
	conn, err := dialFake(addr)
	if err != nil {
		t.Fatal(err)
	}
	c := &fakeCore{conn: conn, state: state, stopped: make(chan struct{})}
	go c.serve()
	return c
}

func (c *fakeCore) serve() {
	defer close(c.stopped)
	for {
		c.mu.Lock()
		conn := c.conn
		c.mu.Unlock()
		for {
			data, err := readFrame(conn)
			if err != nil {
				break
			}
			var action struct {
				Id     string `json:"id"`
				Method string `json:"method"`
				Data   any    `json:"data"`
			}
			_ = json.Unmarshal(data, &action)
			c.handle(conn, action.Id, action.Method, action.Data)
		}
		c.mu.Lock()
		current := c.conn
		c.mu.Unlock()
		if current == conn {
			return
		}
	}
}

func (c *fakeCore) handle(conn net.Conn, id, method string, data any) {
	c.mu.Lock()
	c.calls = append(c.calls, method)
	var result any = ""
	switch method {
	case "getRestoreState":
		result = c.state
	case "initClash":
		c.state.Init, _ = data.(string)
		result = true
	case "setupConfig":
		c.state.Setup, _ = data.(string)
		result = fakeSetupError
	case "startListener":
		c.state.Running = true
		result = true
	case "stopListener":
		c.state.Running = false
		result = true
	case "handover":
		next, err := dialFake(data.(string))
		if err != nil {
			result = err.Error()
			break
		}
		frame, _ := json.Marshal(map[string]any{"id": id, "method": method, "data": "", "code": 0})
		_ = writeFrame(conn, frame)
		c.conn = next
		c.mu.Unlock()
		_ = conn.Close()
		return
	}
	c.mu.Unlock()
	frame, _ := json.Marshal(map[string]any{"id": id, "method": method, "data": result, "code": 0})
	_ = writeFrame(conn, frame)
}

func (c *fakeCore) calledMethods() string {
	c.mu.Lock()
	defer c.mu.Unlock()
	return strings.Join(c.calls, ",")
}

// Every test runs its own tray; pooled connections could reach an old one.
var testClient = &http.Client{Transport: &http.Transport{DisableKeepAlives: true}}

type fakePlatform struct {
	t      *testing.T
	mu     sync.Mutex
	done   chan struct{}
	proxy  []bool
	cores  []*fakeCore
	ui     []bool
	opened int
}

func (p *fakePlatform) runUI(*liteTray) { <-p.done }
func (p *fakePlatform) quitUI()         { close(p.done) }
func (p *fakePlatform) updateUI(running bool) {
	p.mu.Lock()
	p.ui = append(p.ui, running)
	p.mu.Unlock()
}
func (p *fakePlatform) setSystemProxy(enable bool, port int, bypass []string) error {
	p.mu.Lock()
	p.proxy = append(p.proxy, enable)
	p.mu.Unlock()
	return nil
}
func (p *fakePlatform) startCore(path, arg string, helper bool) error {
	core := startFakeCore(p.t, arg, restoreState{})
	p.mu.Lock()
	p.cores = append(p.cores, core)
	p.mu.Unlock()
	return nil
}
func (p *fakePlatform) stopHelperCore() error       { return nil }
func (p *fakePlatform) waitExit(int, time.Duration) {}
func (p *fakePlatform) openApp(string) error        { p.opened++; return nil }

func (p *fakePlatform) proxyCalls() []bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return append([]bool(nil), p.proxy...)
}

// liteSession runs the tray as the app starts it: the app holds the core,
// reads the tray's address from its stdout and hands the core over.
type liteSession struct {
	t     *testing.T
	plat  *fakePlatform
	core  *fakeCore
	state liteState
	ended chan error
}

func startLite(t *testing.T, running bool) *liteSession {
	dir := t.TempDir()
	snap := snapshot{State: filepath.Join(dir, "lite.json"), Core: "core.exe"}
	snap.SystemProxy.Enable = true
	snap.SystemProxy.Port = 7890

	// The app's core, connected to the app.
	appLn, _ := listenCore()
	core := startFakeCore(t, appLn.address(), restoreState{
		Init: `{"home-dir":"h"}`, Engine: "mihomo",
		Setup: `{"selected-map":{},"test-url":"u"}`, Running: running,
	})
	app, err := appLn.accept(5 * time.Second)
	if err != nil {
		t.Fatal(err)
	}

	plat := &fakePlatform{t: t, done: make(chan struct{})}
	lines := make(chan string, 1)
	s := &liteSession{t: t, plat: plat, core: core, ended: make(chan error, 1)}
	go func() { s.ended <- run(snap, plat, func(l string) { lines <- l }) }()

	var line struct{ Core string }
	_ = json.Unmarshal([]byte(<-lines), &line)
	if err := app.callText("handover", line.Core, 5*time.Second); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(5 * time.Second)
	for {
		data, err := os.ReadFile(snap.State)
		if err == nil && json.Unmarshal(data, &s.state) == nil {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("lite.json was not written")
		}
		time.Sleep(10 * time.Millisecond)
	}
	return s
}

func (s *liteSession) post(path string, body any) (*http.Response, []byte) {
	s.t.Helper()
	data, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", fmt.Sprintf("http://127.0.0.1:%d%s", s.state.Port, path), bytes.NewReader(data))
	req.Header.Set("Authorization", "Bearer "+s.state.Token)
	resp, err := testClient.Do(req)
	if err != nil {
		s.t.Fatal(err)
	}
	defer resp.Body.Close()
	var out bytes.Buffer
	_, _ = out.ReadFrom(resp.Body)
	return resp, out.Bytes()
}

func TestLiteTogglesTheCoreAndTheSystemProxy(t *testing.T) {
	s := startLite(t, true)
	if resp, body := s.post("/toggle", nil); resp.StatusCode != 200 {
		t.Fatalf("toggle: %s", body)
	}
	if resp, body := s.post("/toggle", nil); resp.StatusCode != 200 {
		t.Fatalf("toggle: %s", body)
	}
	// Stop ends the core instead of closing its TUN in place; a fresh
	// core without listeners takes over and starts on the next toggle.
	select {
	case <-s.core.stopped:
	case <-time.After(5 * time.Second):
		t.Fatal("stop kept the old core")
	}
	if got := s.core.calledMethods(); got != "handover,getRestoreState,getRestoreState" {
		t.Fatalf("old core calls %s", got)
	}
	if len(s.plat.cores) != 1 {
		t.Fatalf("%d cores started", len(s.plat.cores))
	}
	if got := s.plat.cores[0].calledMethods(); got != "initClash,setupConfig,getRestoreState,startListener" {
		t.Fatalf("new core calls %s", got)
	}
	// The app had set the proxy; the tray turns it off and on again.
	if got := fmt.Sprint(s.plat.proxyCalls()); got != "[false true]" {
		t.Fatalf("system proxy %s", got)
	}
}

func TestLiteRestartReplaysTheStateInANewCore(t *testing.T) {
	s := startLite(t, true)
	if resp, body := s.post("/restart", nil); resp.StatusCode != 200 {
		t.Fatalf("restart: %s", body)
	}
	select {
	case <-s.core.stopped:
	case <-time.After(5 * time.Second):
		t.Fatal("the old core kept its connection")
	}
	if len(s.plat.cores) != 1 {
		t.Fatalf("%d cores started", len(s.plat.cores))
	}
	if got := s.plat.cores[0].calledMethods(); got != "initClash,setupConfig,startListener,getRestoreState" {
		t.Fatalf("new core calls %s", got)
	}
}

func TestLiteHandsTheCoreBackToTheApp(t *testing.T) {
	s := startLite(t, false)
	appLn, _ := listenCore()
	resp, body := s.post("/attach", map[string]string{"address": appLn.address()})
	if resp.StatusCode != 200 {
		t.Fatalf("attach: %s", body)
	}
	var result struct{ Running, Helper bool }
	_ = json.Unmarshal(body, &result)
	if result.Running {
		t.Fatalf("attach reported %s for a stopped core", body)
	}
	app, err := appLn.accept(5 * time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := app.call("getRestoreState", nil, 5*time.Second); err != nil {
		t.Fatalf("the app cannot reach the core: %v", err)
	}
	select {
	case err := <-s.ended:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("the tray kept running after the app took the core")
	}
	if len(s.plat.proxyCalls()) != 0 {
		t.Fatalf("attach touched the system proxy: %v", s.plat.proxyCalls())
	}
}

func TestLiteExitStopsTheCoreAndTheProxy(t *testing.T) {
	s := startLite(t, true)
	s.post("/exit", nil)
	select {
	case <-s.ended:
	case <-time.After(5 * time.Second):
		t.Fatal("the tray did not exit")
	}
	select {
	case <-s.core.stopped:
	case <-time.After(5 * time.Second):
		t.Fatal("the core kept running")
	}
	if got := fmt.Sprint(s.plat.proxyCalls()); got != "[false]" {
		t.Fatalf("system proxy %s", got)
	}
}

func TestLiteControlNeedsTheToken(t *testing.T) {
	s := startLite(t, true)
	resp, err := testClient.Post(fmt.Sprintf("http://127.0.0.1:%d/exit", s.state.Port), "application/json", nil)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("status %d without the token", resp.StatusCode)
	}
	s.post("/exit", nil)
	<-s.ended
}

func TestLiteRestartKeepsACoreWhoseProfileDoesNotApply(t *testing.T) {
	fakeSetupError = "configuration file config.yaml is empty"
	t.Cleanup(func() { fakeSetupError = "" })
	s := startLite(t, false)
	if resp, body := s.post("/restart", nil); resp.StatusCode != 200 {
		t.Fatalf("restart: %s", body)
	}
	if got := s.plat.cores[0].calledMethods(); got != "initClash,setupConfig,getRestoreState" {
		t.Fatalf("new core calls %s", got)
	}
}
