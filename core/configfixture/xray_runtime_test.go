package configfixture

import (
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"testing"

	"core/xray"
)

// Configs written by test/services/xray_config/xray_runtime_config_test.dart
// from a panel-style JSON subscription.
func xrayFixture(t *testing.T, name string) []byte {
	t.Helper()
	buf, err := os.ReadFile(filepath.Join("..", "..", "build", "mihomo-runtime-fixtures", name))
	if err != nil {
		t.Fatalf("Xray runtime fixture missing; run the Flutter tests first: %v", err)
	}
	return buf
}

func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

func TestBundledXrayAcceptsTheAppRuntimeConfig(t *testing.T) {
	tun := xrayFixture(t, "xray_runtime_tun.json")
	if err := xray.Validate(tun); err != nil {
		t.Fatalf("bundled Xray rejected the VPN config: %v", err)
	}
	if !xray.HasTun(tun) {
		t.Fatal("the VPN config must wait for the VpnService fd")
	}

	var config map[string]any
	if err := json.Unmarshal(xrayFixture(t, "xray_runtime.json"), &config); err != nil {
		t.Fatal(err)
	}
	// Fixed ports may be taken on the runner.
	for _, inbound := range config["inbounds"].([]any) {
		inbound.(map[string]any)["port"] = freePort(t)
	}
	buf, _ := json.Marshal(config)
	if err := xray.Start(buf, 0); err != nil {
		t.Fatalf("bundled Xray could not start the app config: %v", err)
	}
	defer xray.Stop()
	if err := xray.SelectOutbound("routami-select", "n001-proxy"); err != nil {
		t.Fatalf("node switch failed: %v", err)
	}
	if err := xray.SelectOutbound("routami-select", "n999-proxy"); err == nil {
		t.Fatal("an unknown node must be rejected")
	}
}
