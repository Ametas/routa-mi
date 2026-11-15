package main

import (
	"crypto/sha256"
	"encoding/hex"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type fakeCore struct{ killed bool }

func (c *fakeCore) Kill() error { c.killed = true; return nil }
func (c *fakeCore) Wait() error { return nil }

type fixture struct {
	h       *helper
	server  *httptest.Server
	caller  string
	spawned []string
	cores   []*fakeCore
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	dir := t.TempDir()
	core := []byte("routami core build")
	if err := os.WriteFile(filepath.Join(dir, coreExeName), core, 0o755); err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(core)
	previous := coreSHA256
	coreSHA256 = hex.EncodeToString(sum[:])
	t.Cleanup(func() { coreSHA256 = previous })

	f := &fixture{caller: filepath.Join(dir, appExeName)}
	f.h = &helper{
		dir:        dir,
		callerPath: func(*http.Request) (string, error) { return f.caller, nil },
		spawn: func(path, arg string, log func(string)) (process, error) {
			f.spawned = append(f.spawned, path+" "+arg)
			log("started " + arg)
			c := &fakeCore{}
			f.cores = append(f.cores, c)
			return c, nil
		},
	}
	f.server = httptest.NewServer(f.h.handler())
	t.Cleanup(f.server.Close)
	return f
}

func (f *fixture) post(t *testing.T, path, body string) (int, string) {
	t.Helper()
	response, err := http.Post(f.server.URL+path, "application/json", strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	data, _ := io.ReadAll(response.Body)
	return response.StatusCode, strings.TrimSpace(string(data))
}

func (f *fixture) startBody(path string) string {
	return `{"path":` + quote(path) + `,"arg":"tcp:5000:token"}`
}

func quote(s string) string { return `"` + strings.ReplaceAll(s, `\`, `\\`) + `"` }

func TestPingReturnsTheCoreHash(t *testing.T) {
	f := newFixture(t)
	response, err := http.Get(f.server.URL + "/ping")
	if err != nil {
		t.Fatal(err)
	}
	data, _ := io.ReadAll(response.Body)
	response.Body.Close()
	if string(data) != coreSHA256 {
		t.Fatalf("ping = %q, want the core hash", data)
	}
}

func TestStartRunsTheBundledCore(t *testing.T) {
	f := newFixture(t)
	corePath := filepath.Join(f.h.dir, coreExeName)
	if status, body := f.post(t, "/start", f.startBody(corePath)); status != http.StatusOK || body != "" {
		t.Fatalf("start = %d %q", status, body)
	}
	if len(f.spawned) != 1 || f.spawned[0] != corePath+" tcp:5000:token" {
		t.Fatalf("spawned %v", f.spawned)
	}
	// A second start replaces the running core.
	f.post(t, "/start", f.startBody(corePath))
	if !f.cores[0].killed || len(f.spawned) != 2 {
		t.Fatal("restart did not stop the previous core")
	}
	if status, _ := f.post(t, "/stop", ""); status != http.StatusOK || !f.cores[1].killed {
		t.Fatal("stop did not kill the core")
	}
	response, _ := http.Get(f.server.URL + "/logs")
	data, _ := io.ReadAll(response.Body)
	response.Body.Close()
	if !strings.Contains(string(data), "started tcp:5000:token") {
		t.Fatalf("logs = %q", data)
	}
}

func TestOnlyTheAppNextToTheHelperMayCall(t *testing.T) {
	f := newFixture(t)
	f.caller = filepath.Join(t.TempDir(), appExeName)
	for _, path := range []string{"/start", "/stop"} {
		if status, _ := f.post(t, path, f.startBody(filepath.Join(f.h.dir, coreExeName))); status != http.StatusForbidden {
			t.Errorf("%s from another RoutaMi.exe: status %d", path, status)
		}
	}
	if len(f.spawned) != 0 {
		t.Fatal("a foreign caller started the core")
	}
}

func TestTheLiteTrayNextToTheHelperMayCall(t *testing.T) {
	f := newFixture(t)
	f.caller = filepath.Join(f.h.dir, trayExeName)
	if status, body := f.post(t, "/stop", ""); status != http.StatusOK {
		t.Fatalf("stop from the tray: %d %s", status, body)
	}
	f.caller = filepath.Join(t.TempDir(), trayExeName)
	if status, _ := f.post(t, "/stop", ""); status != http.StatusForbidden {
		t.Fatalf("stop from another RoutaMiTray.exe: status %d", status)
	}
}

func TestOnlyTheVerifiedCoreStarts(t *testing.T) {
	f := newFixture(t)
	other := filepath.Join(t.TempDir(), coreExeName)
	_ = os.WriteFile(other, []byte("routami core build"), 0o755)
	if _, body := f.post(t, "/start", f.startBody(other)); body == "" {
		t.Error("started a core outside the helper's directory")
	}
	corePath := filepath.Join(f.h.dir, coreExeName)
	_ = os.WriteFile(corePath, []byte("tampered"), 0o755)
	if _, body := f.post(t, "/start", f.startBody(corePath)); !strings.Contains(body, "does not match") {
		t.Errorf("tampered core: %q", body)
	}
	coreSHA256 = ""
	if _, body := f.post(t, "/start", f.startBody(corePath)); body == "" {
		t.Error("a helper built without the hash started the core")
	}
	if len(f.spawned) != 0 {
		t.Fatalf("spawned %v", f.spawned)
	}
}
