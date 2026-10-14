package main

import (
	"encoding/json"
	"errors"
	"sync"

	"core/xray"

	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/log"
)

// RoutaMi runs one core at a time: mihomo for Clash YAML profiles, Xray for
// Xray JSON ones. Switching shuts the other core down so it holds no memory.
type engineKind string

const (
	engineMihomo engineKind = "mihomo"
	engineXray   engineKind = "xray"
)

const (
	xrayValidateMethod Method = "xrayValidate"
	xraySetupMethod    Method = "xraySetup"
	xrayStopMethod     Method = "xrayStop"
	xraySelectMethod   Method = "xraySelect"
	xrayTrafficMethod  Method = "xrayTraffic"
)

var (
	engineLock sync.Mutex
	engine     = engineMihomo
	xrayConfig []byte
)

func activeEngine() engineKind {
	engineLock.Lock()
	defer engineLock.Unlock()
	return engine
}

// xrayTunActive is set by the TUN handler while Xray owns the VPN fd.
var xrayTunActive bool

type xraySelectParams struct {
	Balancer string `json:"balancer"`
	Target   string `json:"target"`
}

type xrayTraffic struct {
	Up   int64 `json:"up"`
	Down int64 `json:"down"`
}

func handleXrayAction(action *Action, result ActionResult) bool {
	switch action.Method {
	case xrayValidateMethod:
		result.success(handleXrayValidate(action.Data.(string)))
	case xraySetupMethod:
		result.success(handleXraySetup(action.Data.(string)))
	case xrayStopMethod:
		handleXrayStop()
		result.success(true)
	case xraySelectMethod:
		var params xraySelectParams
		if err := json.Unmarshal([]byte(action.Data.(string)), &params); err != nil {
			result.success(err.Error())
			return true
		}
		result.success(errorText(xray.SelectOutbound(params.Balancer, params.Target)))
	case xrayTrafficMethod:
		up, down, err := xray.OutboundTraffic(action.Data.(string))
		if err != nil {
			result.error(err.Error())
			return true
		}
		result.success(xrayTraffic{Up: up, Down: down})
	default:
		return false
	}
	return true
}

func errorText(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}

func handleXrayValidate(path string) string {
	buf, err := readFile(path)
	if err != nil {
		return err.Error()
	}
	return errorText(xray.Validate(buf))
}

// handleXraySetup makes Xray the active core with the config at path. It
// shuts mihomo down first. A config with a `tun` inbound waits for the
// VpnService descriptor (startTUN), unless Xray already owns one.
func handleXraySetup(path string) string {
	buf, err := readFile(path)
	if err != nil {
		return err.Error()
	}
	if err := xray.Validate(buf); err != nil {
		return err.Error()
	}
	shutdownMihomoForXray()
	engineLock.Lock()
	engine = engineXray
	xrayConfig = buf
	tunActive := xrayTunActive
	engineLock.Unlock()
	switch {
	case tunActive:
		err = xray.Reload(buf)
	case xray.HasTun(buf):
		xray.Stop()
	default:
		err = xray.Start(buf, 0)
	}
	return errorText(err)
}

// handleXrayStop hands the device back to mihomo; the app sets mihomo up
// again (initClash + setupConfig) as for a fresh start.
func handleXrayStop() {
	xray.Stop()
	engineLock.Lock()
	engine = engineMihomo
	xrayConfig = nil
	engineLock.Unlock()
}

func shutdownMihomoForXray() {
	runLock.Lock()
	defer runLock.Unlock()
	if !isInit && !isRunning {
		return
	}
	log.Infoln("[APP] switching to Xray, shutting mihomo down")
	isRunning = false
	stopListeners()
	executor.Shutdown()
	invalidateProxiesCacheLocked()
	isInit = false
	handleForceGC()
}

// startXrayTun starts the Xray config set up last on the VpnService fd.
func startXrayTun(fd int) error {
	engineLock.Lock()
	buf := xrayConfig
	engineLock.Unlock()
	if buf == nil {
		return errors.New("no Xray config set up")
	}
	if err := xray.Start(buf, fd); err != nil {
		return err
	}
	engineLock.Lock()
	xrayTunActive = true
	engineLock.Unlock()
	return nil
}

func stopXrayTun() {
	engineLock.Lock()
	xrayTunActive = false
	engineLock.Unlock()
	xray.Stop()
}
