//go:build !cgo

package main

import (
	"encoding/json"
	"fmt"
	"net"
	"testing"
	"time"
)

// fakeController is the app (or the tray) on the other end of the IPC.
type fakeController struct {
	t     *testing.T
	ln    net.Listener
	token string
	conn  net.Conn
}

func newFakeController(t *testing.T, token string) *fakeController {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ln.Close() })
	return &fakeController{t: t, ln: ln, token: token}
}

func (f *fakeController) address() string {
	return fmt.Sprintf("tcp:%d:%s", f.ln.Addr().(*net.TCPAddr).Port, f.token)
}

func (f *fakeController) accept() {
	f.t.Helper()
	_ = f.ln.(*net.TCPListener).SetDeadline(time.Now().Add(5 * time.Second))
	c, err := f.ln.Accept()
	if err != nil {
		f.t.Fatal(err)
	}
	token, err := readFrame(c)
	if err != nil || string(token) != f.token {
		f.t.Fatalf("token %q, %v", token, err)
	}
	f.conn = c
	f.t.Cleanup(func() { _ = c.Close() })
}

func (f *fakeController) call(id string, method Method, data any) ActionResult {
	f.t.Helper()
	frame, _ := json.Marshal(Action{Id: id, Method: method, Data: data})
	if err := writeFrame(f.conn, frame); err != nil {
		f.t.Fatal(err)
	}
	_ = f.conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	for {
		data, err := readFrame(f.conn)
		if err != nil {
			f.t.Fatalf("%s: %v", method, err)
		}
		var result ActionResult
		if err := json.Unmarshal(data, &result); err != nil {
			f.t.Fatal(err)
		}
		if result.Id == id {
			return result
		}
	}
}

func TestHandoverKeepsTheCoreForTheNextController(t *testing.T) {
	previous := journal
	t.Cleanup(func() { journal = previous })
	journal = restoreJournal{}

	app := newFakeController(t, "app-token")
	done := make(chan struct{})
	go func() {
		startServer(app.address())
		close(done)
	}()
	app.accept()
	app.call("1", startListenerMethod, nil)

	tray := newFakeController(t, "tray-token")
	if got := app.call("2", handoverMethod, tray.address()); got.Data != "" {
		t.Fatalf("handover = %v", got.Data)
	}
	tray.accept()
	if _, err := readFrame(app.conn); err == nil {
		t.Fatal("the core kept the old controller's connection open")
	}
	select {
	case <-done:
		t.Fatal("the core stopped when the old controller left")
	case <-time.After(100 * time.Millisecond):
	}

	state := tray.call("3", getRestoreStateMethod, nil)
	running, _ := state.Data.(map[string]any)["running"].(bool)
	if !running {
		t.Fatalf("restore state %v lost the running listener", state.Data)
	}

	back := newFakeController(t, "app-again")
	if got := tray.call("4", handoverMethod, back.address()); got.Data != "" {
		t.Fatalf("handover back = %v", got.Data)
	}
	back.accept()
	if got := back.call("5", getIsInitMethod, nil); got.Code != 0 {
		t.Fatalf("getIsInit after handover back = %+v", got)
	}

	_ = back.conn.Close()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("the core outlived its current controller")
	}
}

func TestHandoverToAMissingControllerKeepsTheCurrentOne(t *testing.T) {
	app := newFakeController(t, "app-token")
	done := make(chan struct{})
	go func() {
		startServer(app.address())
		close(done)
	}()
	app.accept()
	gone := newFakeController(t, "gone")
	addr := gone.address()
	_ = gone.ln.Close()
	if got := app.call("1", handoverMethod, addr); got.Data == "" {
		t.Fatal("a failed handover reported success")
	}
	if got := app.call("2", getIsInitMethod, nil); got.Code != 0 {
		t.Fatalf("the old controller lost the core: %+v", got)
	}
	_ = app.conn.Close()
	<-done
}

func TestRestoreJournalReplaysTheLatestState(t *testing.T) {
	var j restoreJournal
	str := func(v string) *string { return &v }
	change := func(group, proxy string) *Action {
		data, _ := json.Marshal(ChangeProxyParams{GroupName: str(group), ProxyName: str(proxy)})
		return &Action{Method: changeProxyMethod, Data: string(data)}
	}
	j.record(&Action{Method: initClashMethod, Data: `{"home-dir":"h"}`})
	j.record(&Action{Method: updateConfigMethod, Data: `{"mode":"rule"}`})
	j.record(&Action{Method: setupConfigMethod, Data: `{"selected-map":{"A":"a1","B":"b1"},"test-url":"u"}`})
	j.record(change("A", "a2"))
	j.record(&Action{Method: updateConfigMethod, Data: `{"mode":"global"}`})
	j.record(&Action{Method: startListenerMethod})

	state := j.snapshot()
	if state.Init != `{"home-dir":"h"}` || state.Engine != "mihomo" || !state.Running {
		t.Fatalf("state %+v", state)
	}
	if state.Update != `{"mode":"global"}` {
		t.Fatalf("update %q: want only the one after the setup", state.Update)
	}
	var setup SetupParams
	if err := json.Unmarshal([]byte(state.Setup), &setup); err != nil {
		t.Fatal(err)
	}
	if setup.SelectedMap["A"] != "a2" || setup.SelectedMap["B"] != "b1" || setup.TestURL != "u" {
		t.Fatalf("setup %+v", setup)
	}

	j.record(&Action{Method: xraySetupMethod, Data: `{"path":"x"}`})
	j.record(&Action{Method: xraySelectMethod, Data: `{"target":"t"}`})
	j.record(&Action{Method: stopListenerMethod})
	state = j.snapshot()
	if state.Engine != "xray" || state.XraySetup != `{"path":"x"}` || state.XraySelect != `{"target":"t"}` || state.Running {
		t.Fatalf("xray state %+v", state)
	}
}
