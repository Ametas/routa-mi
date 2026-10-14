package main

import (
	"encoding/json"
	"errors"
	"path/filepath"
	"sync"

	"core/xray"

	"github.com/metacubex/mihomo/constant"
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
	// xraySelection is the node the user picked; it is applied after every
	// start, so a restart or a new TUN keeps it.
	xraySelection xraySelectParams
	// lastInitParams lets setupConfig bring mihomo back after Xray.
	lastInitParams string
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

type xraySetupParams struct {
	Path string `json:"path"`
	xraySelectParams
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
		result.success(errorText(handleXraySelect(params)))
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

// prepareXrayAssets lets Xray rules use mihomo's GeoIP/GeoSite files.
func prepareXrayAssets() {
	home := constant.Path.HomeDir()
	if err := xray.UseGeoData(filepath.Join(home, "xray-assets"), constant.Path.GeoIP(), constant.Path.GeoSite()); err != nil {
		log.Warnln("[Xray] geo data: %v", err)
	}
}

func handleXrayValidate(path string) string {
	prepareXrayAssets()
	buf, err := readFile(path)
	if err != nil {
		return err.Error()
	}
	return errorText(xray.Validate(buf))
}

// handleXraySetup makes Xray the active core with the config at params.Path
// and the node in params. It shuts mihomo down first. A config with a `tun`
// inbound waits for the VpnService descriptor (startTUN), unless Xray
// already owns one.
func handleXraySetup(paramsString string) string {
	var params xraySetupParams
	if err := json.Unmarshal([]byte(paramsString), &params); err != nil {
		return err.Error()
	}
	prepareXrayAssets()
	buf, err := readFile(params.Path)
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
	xraySelection = params.xraySelectParams
	tunActive := xrayTunActive
	engineLock.Unlock()
	setXrayProxyTags(buf, params.Balancer)
	switch {
	case tunActive:
		err = xray.Reload(buf)
	case xray.HasTun(buf):
		xray.Stop()
		return ""
	default:
		err = xray.Start(buf, 0)
	}
	if err != nil {
		return err.Error()
	}
	return errorText(applyXraySelection())
}

func handleXraySelect(params xraySelectParams) error {
	engineLock.Lock()
	xraySelection = params
	engineLock.Unlock()
	if !xray.Running() {
		return nil // applied when Xray starts
	}
	return applyXraySelection()
}

func applyXraySelection() error {
	engineLock.Lock()
	selection := xraySelection
	engineLock.Unlock()
	if selection.Balancer == "" || selection.Target == "" {
		return nil
	}
	return xray.SelectOutbound(selection.Balancer, selection.Target)
}

// handleXrayStop hands the device back to mihomo; the app sets mihomo up
// again (initClash + setupConfig) as for a fresh start.
func handleXrayStop() {
	xray.Stop()
	engineLock.Lock()
	engine = engineMihomo
	xrayConfig = nil
	xraySelection = xraySelectParams{}
	engineLock.Unlock()
}

// switchBackToMihomoLocked runs before every mihomo setup (runLock held):
// a mihomo profile after an Xray one stops Xray and initialises mihomo
// again with the app's last init params.
func switchBackToMihomoLocked() {
	if activeEngine() != engineXray {
		return
	}
	log.Infoln("[APP] switching back to mihomo")
	handleXrayStop()
	if !isInit && lastInitParams != "" {
		initClashLocked(lastInitParams)
	}
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
	if err := applyXraySelection(); err != nil {
		log.Warnln("[Xray] node selection: %v", err)
	}
	return nil
}

func stopXrayTun() {
	engineLock.Lock()
	xrayTunActive = false
	engineLock.Unlock()
	xray.Stop()
}
