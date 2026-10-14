// Package xray runs Xray-core as RoutaMi's second core, in the same process
// as mihomo. Only one core runs at a time: starting Xray is the caller's cue
// to stop mihomo and the other way round, and Stop returns the memory.
package xray

import (
	"bytes"
	"errors"
	"os"
	"runtime"
	"runtime/debug"
	"strconv"
	"strings"
	"sync"
	"syscall"

	"github.com/xtls/xray-core/common/platform"
	"github.com/xtls/xray-core/core"
	"github.com/xtls/xray-core/features/routing"
	"github.com/xtls/xray-core/features/stats"
	"github.com/xtls/xray-core/infra/conf/serial"

	// Every protocol and transport, like the stock xray binary.
	_ "github.com/xtls/xray-core/main/distro/all"
)

var (
	mu       sync.Mutex
	instance *core.Instance
	tunFd    int
)

// ErrNotRunning is returned by calls that need a running instance.
var ErrNotRunning = errors.New("xray is not running")

// Load parses an Xray JSON config.
func Load(buf []byte) (*core.Config, error) {
	return serial.LoadJSONConfig(bytes.NewReader(buf))
}

// Validate reports whether buf is an Xray JSON config the core accepts.
func Validate(buf []byte) error {
	_, err := Load(buf)
	return err
}

// Start replaces any running instance with one built from buf. A positive
// fd is the VpnService TUN for the config's `tun` inbound; the engine owns
// it from then on and closes it on Stop or when the start fails.
func Start(buf []byte, fd int) error {
	mu.Lock()
	defer mu.Unlock()
	stopLocked()
	config, err := Load(buf)
	if err != nil {
		closeFd(fd)
		return err
	}
	if fd > 0 {
		_ = os.Setenv(platform.TunFdKey, strconv.Itoa(fd))
	} else {
		_ = os.Unsetenv(platform.TunFdKey)
	}
	next, err := core.New(config)
	if err != nil {
		closeFd(fd)
		return err
	}
	if err := next.Start(); err != nil {
		_ = next.Close()
		closeFd(fd)
		return err
	}
	instance, tunFd = next, fd
	return nil
}

// Reload swaps the running config for buf and keeps the TUN descriptor,
// so a settings change does not need a new VpnService interface.
func Reload(buf []byte) error {
	mu.Lock()
	defer mu.Unlock()
	config, err := Load(buf)
	if err != nil {
		return err
	}
	if instance != nil {
		_ = instance.Close()
		instance = nil
	}
	next, err := core.New(config)
	if err == nil {
		if err = next.Start(); err != nil {
			_ = next.Close()
		}
	}
	if err != nil {
		closeFd(tunFd)
		tunFd = 0
		return err
	}
	instance = next
	return nil
}

// HasTun reports whether the config has a `tun` inbound, which only starts
// once the VpnService hands over its descriptor.
func HasTun(buf []byte) bool {
	config, err := serial.DecodeJSONConfig(bytes.NewReader(buf))
	if err != nil {
		return false
	}
	for _, inbound := range config.InboundConfigs {
		if strings.EqualFold(inbound.Protocol, "tun") {
			return true
		}
	}
	return false
}

// Stop closes the running instance, if any, and hands its memory back to
// the system so an idle Xray costs nothing while mihomo runs.
func Stop() {
	mu.Lock()
	defer mu.Unlock()
	stopLocked()
}

func stopLocked() {
	if instance == nil && tunFd <= 0 {
		return
	}
	if instance != nil {
		_ = instance.Close()
		instance = nil
	}
	// Xray's Android TUN does not close the descriptor itself.
	closeFd(tunFd)
	tunFd = 0
	runtime.GC()
	debug.FreeOSMemory()
}

// Running reports whether an instance is up.
func Running() bool {
	mu.Lock()
	defer mu.Unlock()
	return instance != nil
}

// SelectOutbound points balancer at target without a restart: the node
// list of a profile is one balancer whose target the user picks.
func SelectOutbound(balancer, target string) error {
	mu.Lock()
	defer mu.Unlock()
	if instance == nil {
		return ErrNotRunning
	}
	overrider, ok := instance.GetFeature(routing.RouterType()).(routing.BalancerOverrider)
	if !ok {
		return errors.New("xray router does not support balancer overrides")
	}
	return overrider.SetOverrideTarget(balancer, target)
}

// OutboundTraffic returns the bytes sent and received through the outbound
// tag since start. The config must enable `stats` and the outbound
// counters of the system policy.
func OutboundTraffic(tag string) (up, down int64, err error) {
	mu.Lock()
	defer mu.Unlock()
	if instance == nil {
		return 0, 0, ErrNotRunning
	}
	manager, ok := instance.GetFeature(stats.ManagerType()).(stats.Manager)
	if !ok {
		return 0, 0, errors.New("xray stats are not enabled")
	}
	if counter := manager.GetCounter("outbound>>>" + tag + ">>>traffic>>>uplink"); counter != nil {
		up = counter.Value()
	}
	if counter := manager.GetCounter("outbound>>>" + tag + ">>>traffic>>>downlink"); counter != nil {
		down = counter.Value()
	}
	return up, down, nil
}

func closeFd(fd int) {
	if fd > 0 {
		_ = syscall.Close(fd)
	}
}
