package configfixture

import (
	"encoding/binary"
	"io"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/listener"
	"gopkg.in/yaml.v3"
)

// The app-owned plain VLESS inbound (lib/common/local_vless.dart), as written
// by test/settings/local_vless_test.dart.
const localVlessListenerName = "routami-vless"

type recordingTunnel struct{ conns chan *C.Metadata }

func (t *recordingTunnel) HandleTCPConn(conn net.Conn, metadata *C.Metadata) {
	t.conns <- metadata
	_ = conn.Close()
}

func (t *recordingTunnel) HandleUDPPacket(C.UDPPacket, *C.Metadata) {}

func (t *recordingTunnel) NatTable() C.NatTable { return nil }

func localVlessListener(t *testing.T) map[string]any {
	t.Helper()
	contents, err := os.ReadFile(filepath.Join("..", "..", "build", "mihomo-runtime-fixtures", "local_vless.yaml"))
	if err != nil {
		t.Fatalf("processed runtime fixture is missing; run the Flutter tests first: %v", err)
	}
	if _, err := config.Parse(contents); err != nil {
		t.Fatalf("bundled Mihomo rejected local_vless.yaml: %v", err)
	}
	var raw struct {
		Listeners []map[string]any `yaml:"listeners"`
	}
	if err := yaml.Unmarshal(contents, &raw); err != nil {
		t.Fatal(err)
	}
	for _, item := range raw.Listeners {
		if item["name"] == localVlessListenerName {
			return item
		}
	}
	t.Fatalf("%s listener is missing", localVlessListenerName)
	return nil
}

func startLocalVless(t *testing.T, mapping map[string]any) (string, *recordingTunnel, error) {
	t.Helper()
	mapping["port"] = 0 // The fixture's fixed port may be taken on the runner.
	in, err := listener.ParseListener(mapping)
	if err != nil {
		t.Fatal(err)
	}
	tunnel := &recordingTunnel{conns: make(chan *C.Metadata, 1)}
	if err := in.Listen(tunnel); err != nil {
		return "", nil, err
	}
	t.Cleanup(func() { _ = in.Close() })
	return in.Address(), tunnel, nil
}

// vlessRequest is a VLESS v0 TCP request to 1.2.3.4:443 without addons.
func vlessRequest(t *testing.T, uuid string) []byte {
	t.Helper()
	id := utils.UUIDMap(uuid)
	request := []byte{0}
	request = append(request, id.Bytes()...)
	request = append(request, 0, 1) // no addons, TCP
	request = binary.BigEndian.AppendUint16(request, 443)
	request = append(request, 1, 1, 2, 3, 4) // IPv4
	return append(request, []byte("hello")...)
}

func dialLocalVless(t *testing.T, address string, uuid string) {
	t.Helper()
	conn, err := net.DialTimeout("tcp", address, 5*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	if _, err := conn.Write(vlessRequest(t, uuid)); err != nil {
		t.Fatal(err)
	}
	_ = conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, _ = io.Copy(io.Discard, conn)
}

func TestLocalVlessListenerAcceptsOnlyItsUUID(t *testing.T) {
	mapping := localVlessListener(t)
	if mapping["listen"] != "127.0.0.1" {
		t.Fatalf("listen = %v, want loopback", mapping["listen"])
	}
	users := mapping["users"].([]any)
	uuid := users[0].(map[string]any)["uuid"].(string)
	address, tunnel, err := startLocalVless(t, mapping)
	if err != nil {
		t.Fatalf("bundled Mihomo refused the plain VLESS listener: %v", err)
	}

	dialLocalVless(t, address, utils.NewUUIDV4().String())
	select {
	case metadata := <-tunnel.conns:
		t.Fatalf("a wrong UUID reached the tunnel: %v", metadata.RemoteAddress())
	default:
	}

	dialLocalVless(t, address, uuid)
	select {
	case metadata := <-tunnel.conns:
		if got := metadata.RemoteAddress(); got != "1.2.3.4:443" {
			t.Fatalf("destination = %s, want 1.2.3.4:443", got)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("the app UUID did not reach the tunnel")
	}
}

func TestPlainVlessListenerNeedsAllowInsecure(t *testing.T) {
	mapping := localVlessListener(t)
	delete(mapping, "allow-insecure")
	if _, _, err := startLocalVless(t, mapping); err == nil {
		t.Fatal("mihomo now accepts plain VLESS without allow-insecure; the app flag may be dropped")
	}
}
