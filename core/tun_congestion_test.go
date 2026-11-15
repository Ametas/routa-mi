package main

import (
	"encoding/json"
	"testing"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
)

func TestTunPatchCarriesMipsCongestionControl(t *testing.T) {
	previous, running := currentConfig, isRunning
	t.Cleanup(func() { currentConfig, isRunning = previous, running })
	currentConfig = &config.Config{General: &config.General{}, Controller: &config.Controller{}}
	isRunning = false

	apply := func(patch string) {
		t.Helper()
		var params UpdateParams
		if err := json.Unmarshal([]byte(patch), &params); err != nil {
			t.Fatal(err)
		}
		if err := updateConfig(&params); err != nil {
			t.Fatalf("updateConfig: %v", err)
		}
	}
	base := `"enable":false,"device":"RoutaMi","auto-route":true,"dns-hijack":["any:53"],"route-address":[]`

	apply(`{"tun":{` + base + `,"stack":"mips","congestion-controller":"bbr"}}`)
	if got := currentConfig.General.Tun.Stack; got != constant.TunMips {
		t.Fatalf("stack = %v, want mips", got)
	}
	if got := tunCongestionController(); got != "bbr" {
		t.Fatalf("congestion = %q, want bbr", got)
	}

	// The app leaves the key out (null) when the user has not picked one.
	apply(`{"tun":{` + base + `,"stack":"mips","congestion-controller":null}}`)
	if got := tunCongestionController(); got != "bbr" {
		t.Fatalf("congestion = %q after a patch without it, want bbr kept", got)
	}
}

func TestTunCongestionControllerWithoutConfig(t *testing.T) {
	previous := currentConfig
	t.Cleanup(func() { currentConfig = previous })
	currentConfig = nil
	if got := tunCongestionController(); got != "" {
		t.Fatalf("congestion = %q, want empty", got)
	}
}
