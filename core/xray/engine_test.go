package xray

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"golang.org/x/net/proxy"
)

func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

// config: a local socks inbound routed to a balancer over a working and a
// blackholed outbound, like a profile's node list.
func config(port int) string {
	return fmt.Sprintf(`{
  "log": {"loglevel": "info"},
  "stats": {},
  "policy": {"system": {"statsOutboundUplink": true, "statsOutboundDownlink": true}},
  "inbounds": [{"tag": "socks-in", "listen": "127.0.0.1", "port": %d, "protocol": "socks", "settings": {"udp": false}}],
  "outbounds": [
    {"tag": "node-ok", "protocol": "freedom"},
    {"tag": "node-dead", "protocol": "blackhole"}
  ],
  "routing": {
    "balancers": [{"tag": "routami-select", "selector": ["node-ok", "node-dead"]}],
    "rules": [{"type": "field", "inboundTag": ["socks-in"], "balancerTag": "routami-select"}]
  }
}`, port)
}

func fetch(t *testing.T, port int, url string) error {
	t.Helper()
	dialer, err := proxy.SOCKS5("tcp", fmt.Sprintf("127.0.0.1:%d", port), nil, proxy.Direct)
	if err != nil {
		t.Fatal(err)
	}
	client := &http.Client{
		Timeout:   3 * time.Second,
		Transport: &http.Transport{Dial: dialer.Dial, DisableKeepAlives: true},
	}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	if string(body) != "ok" {
		return fmt.Errorf("body %q", body)
	}
	return nil
}

func TestValidate(t *testing.T) {
	if err := Validate([]byte(config(1080))); err != nil {
		t.Fatalf("valid config rejected: %v", err)
	}
	if err := Validate([]byte(`{"outbounds": [{"protocol": "no-such"}]}`)); err == nil {
		t.Fatal("an unknown protocol must be rejected")
	}
	if err := Validate([]byte("proxies: []")); err == nil {
		t.Fatal("a Clash YAML config is not an Xray config")
	}
}

func TestNodeSwitchWithoutRestartAndTraffic(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = io.WriteString(w, "ok")
	}))
	defer server.Close()

	var mu sync.Mutex
	var lines []string
	SetLogHandler(func(message string) {
		mu.Lock()
		lines = append(lines, message)
		mu.Unlock()
	})
	defer SetLogHandler(nil)

	port := freePort(t)
	if err := Start([]byte(config(port)), 0); err != nil {
		t.Fatal(err)
	}
	defer Stop()
	if !Running() {
		t.Fatal("not running after Start")
	}

	if err := SelectOutbound("routami-select", "node-dead"); err != nil {
		t.Fatal(err)
	}
	if err := fetch(t, port, server.URL); err == nil {
		t.Fatal("the blackholed node must not reach the server")
	}
	// Same instance, other node: no restart in between.
	if err := SelectOutbound("routami-select", "node-ok"); err != nil {
		t.Fatal(err)
	}
	if err := fetch(t, port, server.URL); err != nil {
		t.Fatalf("the working node must reach the server: %v", err)
	}

	// Counters settle when Xray finishes copying, after the client is done.
	var up, down int64
	for deadline := time.Now().Add(3 * time.Second); ; {
		var err error
		up, down, err = OutboundTraffic("node-ok")
		if err != nil {
			t.Fatal(err)
		}
		if (up > 0 && down > 0) || time.Now().After(deadline) {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if up == 0 || down == 0 {
		t.Fatalf("traffic not counted: up=%d down=%d", up, down)
	}

	mu.Lock()
	logged := strings.Join(lines, "\n")
	mu.Unlock()
	if !strings.Contains(logged, "Xray") {
		t.Fatalf("console log did not reach the handler: %q", logged)
	}
}

func TestStopReleasesTheInstance(t *testing.T) {
	port := freePort(t)
	if err := Start([]byte(config(port)), 0); err != nil {
		t.Fatal(err)
	}
	Stop()
	if Running() {
		t.Fatal("still running after Stop")
	}
	if err := SelectOutbound("routami-select", "node-ok"); err != ErrNotRunning {
		t.Fatalf("got %v", err)
	}
	// The port is free again: the inbound really went away.
	l, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", port))
	if err != nil {
		t.Fatalf("inbound still listening: %v", err)
	}
	l.Close()
	if err := Start([]byte("{"), 0); err == nil || Running() {
		t.Fatal("a broken config must not leave an instance behind")
	}
}
