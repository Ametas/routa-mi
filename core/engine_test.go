package main

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"testing"

	"core/xray"
)

func writeXrayConfig(t *testing.T, inbound string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "config.json")
	config := fmt.Sprintf(`{"inbounds": [%s], "outbounds": [{"protocol": "freedom"}]}`, inbound)
	if err := os.WriteFile(path, []byte(config), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

func setupParams(path string) string {
	return fmt.Sprintf(`{"path": %q}`, path)
}

func socksInbound(t *testing.T) (string, int) {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := l.Addr().(*net.TCPAddr).Port
	l.Close()
	return fmt.Sprintf(`{"listen": "127.0.0.1", "port": %d, "protocol": "socks"}`, port), port
}

func TestXraySetupReplacesMihomoAndStopHandsBack(t *testing.T) {
	t.Cleanup(handleXrayStop)
	previousInit, previousRunning := isInit, isRunning
	t.Cleanup(func() { isInit, isRunning = previousInit, previousRunning })
	isInit = true // mihomo was set up before the Xray profile was chosen.

	inbound, port := socksInbound(t)
	if msg := handleXraySetup(setupParams(writeXrayConfig(t, inbound))); msg != "" {
		t.Fatal(msg)
	}
	if activeEngine() != engineXray || !xray.Running() {
		t.Fatal("Xray is not the running core")
	}
	if isInit || isRunning {
		t.Fatal("mihomo must be shut down while Xray runs")
	}
	conn, err := net.Dial("tcp", fmt.Sprintf("127.0.0.1:%d", port))
	if err != nil {
		t.Fatalf("Xray inbound not listening: %v", err)
	}
	conn.Close()

	handleXrayStop()
	if activeEngine() != engineMihomo || xray.Running() {
		t.Fatal("stop must hand the device back to mihomo")
	}
}

func TestXrayTunConfigWaitsForTheVpnDescriptor(t *testing.T) {
	t.Cleanup(handleXrayStop)
	path := writeXrayConfig(t, `{"port": 0, "protocol": "tun", "settings": {"name": "xray0", "mtu": 9000}}`)
	if msg := handleXraySetup(setupParams(path)); msg != "" {
		t.Fatal(msg)
	}
	if activeEngine() != engineXray {
		t.Fatal("Xray must be the active core")
	}
	if xray.Running() {
		t.Fatal("a TUN config starts only with the VpnService fd (startTUN)")
	}
}

func TestXrayInvalidConfigKeepsMihomo(t *testing.T) {
	t.Cleanup(handleXrayStop)
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte(`{"outbounds": [{"protocol": "no-such"}]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if msg := handleXrayValidate(path); msg == "" {
		t.Fatal("validate must reject the config")
	}
	if msg := handleXraySetup(setupParams(path)); msg == "" {
		t.Fatal("setup must reject the config")
	}
	if activeEngine() != engineMihomo {
		t.Fatal("a rejected Xray config must not switch cores")
	}
}

func TestMihomoSetupAfterXrayReinitialisesMihomo(t *testing.T) {
	t.Cleanup(handleXrayStop)
	previous := lastInitParams
	t.Cleanup(func() { lastInitParams = previous })
	home := t.TempDir()
	if !handleInitClash(fmt.Sprintf(`{"home-dir": %q, "version": 1}`, home)) {
		t.Fatal("init failed")
	}
	inbound, _ := socksInbound(t)
	if msg := handleXraySetup(setupParams(writeXrayConfig(t, inbound))); msg != "" {
		t.Fatal(msg)
	}
	if isInit {
		t.Fatal("mihomo must be down while Xray runs")
	}

	runLock.Lock()
	switchBackToMihomoLocked()
	initialised := isInit
	runLock.Unlock()
	if activeEngine() != engineMihomo || xray.Running() {
		t.Fatal("a mihomo setup must stop Xray")
	}
	if !initialised {
		t.Fatal("mihomo must be initialised again with the last init params")
	}
	if !handleStartListener() || !isRunning {
		t.Fatal("mihomo listeners start again once Xray is gone")
	}
	handleStopListener()
}

func TestXraySelectionIsKeptAcrossStarts(t *testing.T) {
	t.Cleanup(handleXrayStop)
	_, port := socksInbound(t)
	config := fmt.Sprintf(`{
  "inbounds": [{"tag": "in", "listen": "127.0.0.1", "port": %d, "protocol": "socks"}],
  "outbounds": [{"tag": "n0-proxy", "protocol": "freedom"}, {"tag": "n1-proxy", "protocol": "blackhole"}],
  "routing": {"balancers": [{"tag": "routami-select", "selector": ["n0-proxy", "n1-proxy"]}],
              "rules": [{"inboundTag": ["in"], "balancerTag": "routami-select"}]}
}`, port)
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte(config), 0o600); err != nil {
		t.Fatal(err)
	}
	params := fmt.Sprintf(`{"path": %q, "balancer": "routami-select", "target": "n1-proxy"}`, path)
	if msg := handleXraySetup(params); msg != "" {
		t.Fatal(msg)
	}
	if err := handleXraySelect(xraySelectParams{Balancer: "routami-select", Target: "n0-proxy"}); err != nil {
		t.Fatal(err)
	}
	if err := handleXraySelect(xraySelectParams{Balancer: "routami-select", Target: "no-such"}); err == nil {
		t.Fatal("an unknown node must be rejected")
	}
	if !handleStartListener() || isRunning {
		t.Fatal("mihomo listeners must stay off while Xray runs")
	}
	if msg := handleUpdateConfig([]byte(`{"mixed-port": 7890}`)); msg != "" {
		t.Fatalf("hot mihomo updates are ignored under Xray: %s", msg)
	}
}

func TestXrayTrafficSnapshotCountsNodes(t *testing.T) {
	t.Cleanup(handleXrayStop)
	_, port := socksInbound(t)
	config := fmt.Sprintf(`{
  "stats": {},
  "policy": {"system": {"statsOutboundUplink": true, "statsOutboundDownlink": true}},
  "inbounds": [{"tag": "in", "listen": "127.0.0.1", "port": %d, "protocol": "socks"}],
  "outbounds": [{"tag": "n000-proxy", "protocol": "freedom"}, {"tag": "routami-direct", "protocol": "freedom"}],
  "routing": {"balancers": [{"tag": "routami-select", "selector": ["n000-proxy"]}],
              "rules": [{"inboundTag": ["in"], "balancerTag": "routami-select"}]}
}`, port)
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte(config), 0o600); err != nil {
		t.Fatal(err)
	}
	if msg := handleXraySetup(fmt.Sprintf(`{"path": %q, "balancer": "routami-select", "target": "n000-proxy"}`, path)); msg != "" {
		t.Fatal(msg)
	}
	var snapshot map[string]int64
	if err := json.Unmarshal([]byte(handleGetTrafficSnapshot(true)), &snapshot); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"up", "down", "totalUp", "totalDown"} {
		if _, ok := snapshot[key]; !ok {
			t.Fatalf("snapshot lacks %s: %v", key, snapshot)
		}
	}
	if !xrayProxyTags["n000-proxy"] || xrayProxyTags["routami-direct"] {
		t.Fatalf("proxy tags: %v", xrayProxyTags)
	}
}
