package main

import (
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
	if msg := handleXraySetup(writeXrayConfig(t, inbound)); msg != "" {
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
	if msg := handleXraySetup(path); msg != "" {
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
	if msg := handleXraySetup(path); msg == "" {
		t.Fatal("setup must reject the config")
	}
	if activeEngine() != engineMihomo {
		t.Fatal("a rejected Xray config must not switch cores")
	}
}
