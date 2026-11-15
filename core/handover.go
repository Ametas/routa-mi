//go:build !cgo

package main

import (
	"encoding/json"
	"io"
	"os"
	"sync"
)

// The Windows core outlives its controller in lite mode: the app hands the
// IPC connection over to RoutaMiTray.exe and exits, and the tray hands it
// back when the window is reopened. The core exits only when the connection
// of its current controller drops.

const (
	handoverMethod        Method = "handover"
	getRestoreStateMethod Method = "getRestoreState"
)

func currentConn() io.ReadWriteCloser {
	connMu.Lock()
	defer connMu.Unlock()
	return conn
}

// serveConns reads actions from the current controller until a connection
// that is still current fails.
func serveConns(read func(io.ReadWriteCloser) error) {
	for {
		c := currentConn()
		err := read(c)
		if currentConn() == c {
			if err != nil && err != io.EOF {
				logError("server read error: %v", err)
			}
			_ = c.Close()
			return
		}
	}
}

// handleHandover dials the controller at addr ("tcp:PORT:TOKEN"), answers
// the old controller, then makes the new one current. The reply goes on the
// old connection because the action came from it.
func handleHandover(addr string, result ActionResult) {
	next, err := dialCore(addr)
	if err != nil {
		result.success(err.Error())
		return
	}
	result.Code = 0
	result.Data = ""
	data, _ := result.Json()

	connMu.Lock()
	old := conn
	_ = writeFrame(old, data)
	conn = next
	connMu.Unlock()
	_ = old.Close()
}

// restoreState is what a controller needs to start a new core in the state
// of this one: the last init, profile and settings actions and whether the
// listeners run. Lite mode's "restart core" replays it without the app.
type restoreState struct {
	Init       string `json:"init"`
	Engine     string `json:"engine"`
	Setup      string `json:"setup,omitempty"`
	Update     string `json:"update,omitempty"`
	XraySetup  string `json:"xraySetup,omitempty"`
	XraySelect string `json:"xraySelect,omitempty"`
	Running    bool   `json:"running"`
	// Pid lets the controller wait for this core to exit before a restart.
	Pid int `json:"pid"`
}

type restoreJournal struct {
	mu       sync.Mutex
	state    restoreState
	selected map[string]string // group -> proxy chosen after the setup
}

var journal restoreJournal

// record keeps the actions that shape the core's state.
func (j *restoreJournal) record(action *Action) {
	data, _ := action.Data.(string)
	j.mu.Lock()
	defer j.mu.Unlock()
	switch action.Method {
	case initClashMethod:
		j.state.Init = data
	case setupConfigMethod:
		j.state.Engine = string(engineMihomo)
		j.state.Setup = data
		// The setup carries the whole patch: older settings no longer apply.
		j.state.Update = ""
		j.selected = nil
	case updateConfigMethod:
		j.state.Update = data
	case changeProxyMethod:
		var params ChangeProxyParams
		if json.Unmarshal([]byte(data), &params) == nil && params.GroupName != nil && params.ProxyName != nil {
			if j.selected == nil {
				j.selected = map[string]string{}
			}
			j.selected[*params.GroupName] = *params.ProxyName
		}
	case xraySetupMethod:
		j.state.Engine = string(engineXray)
		j.state.XraySetup = data
		j.state.XraySelect = ""
	case xraySelectMethod:
		j.state.XraySelect = data
	case startListenerMethod:
		j.state.Running = true
	case stopListenerMethod, shutdownMethod:
		j.state.Running = false
	}
}

// snapshot returns the state with the proxies picked since the setup merged
// into its selected-map.
func (j *restoreJournal) snapshot() restoreState {
	j.mu.Lock()
	defer j.mu.Unlock()
	state := j.state
	state.Pid = os.Getpid()
	if state.Setup == "" || len(j.selected) == 0 {
		return state
	}
	var setup map[string]any
	if json.Unmarshal([]byte(state.Setup), &setup) != nil {
		return state
	}
	selected, _ := setup["selected-map"].(map[string]any)
	if selected == nil {
		selected = map[string]any{}
	}
	for group, proxy := range j.selected {
		selected[group] = proxy
	}
	setup["selected-map"] = selected
	if data, err := json.Marshal(setup); err == nil {
		state.Setup = string(data)
	}
	return state
}

// handleDesktopAction serves the actions only the Windows core has.
func handleDesktopAction(action *Action, result ActionResult) bool {
	switch action.Method {
	case handoverMethod:
		addr, _ := action.Data.(string)
		handleHandover(addr, result)
	case getRestoreStateMethod:
		result.success(journal.snapshot())
	default:
		return false
	}
	return true
}
