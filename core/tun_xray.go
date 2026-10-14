//go:build cgo

package main

import (
	"core/platform"
	"core/xray"

	"github.com/metacubex/mihomo/log"
)

// startXray hands the VpnService fd to Xray's `tun` inbound. Xray dials
// through the same protect callback as mihomo so its sockets stay outside
// the tunnel.
func (th *TunHandler) startXray(fd int) bool {
	runLock.Lock()
	defer runLock.Unlock()
	th.xray = true
	xray.SetProtect(func(fd int) bool {
		if platform.ShouldBlockConnection() {
			return false
		}
		th.handleProtect(fd)
		return true
	})
	if err := startXrayTun(fd); err != nil {
		log.Errorln("Start Xray TUN failed: %v", err)
		th.clear()
		return false
	}
	return true
}

func (th *TunHandler) stopXray() {
	if !th.xray {
		return
	}
	th.xray = false
	stopXrayTun()
	xray.SetProtect(nil)
}
