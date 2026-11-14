//go:build with_naive && with_purego

package naive

import (
	"bufio"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/binary"
	"encoding/pem"
	"errors"
	"io"
	"math/big"
	"net"
	"net/http"
	"net/netip"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/component/dialer"
	C "github.com/metacubex/mihomo/constant"
	cronet "github.com/sagernet/cronet-go"
)

const (
	testUser     = "routami"
	testPassword = "naive-secret"
	testSNI      = "naive.test"
)

// Host tests load the prebuilt libcronet.so/.dll through purego; Android
// links the static library instead (lib_android_arm64.go).
func TestMain(m *testing.M) {
	module := "github.com/sagernet/cronet-go/lib/" + runtime.GOOS + "_" + runtime.GOARCH
	library := "libcronet.so"
	if runtime.GOOS == "windows" {
		library = "libcronet.dll"
	}
	out, err := exec.Command("go", "list", "-m", "-f", "{{.Dir}}", module).Output()
	if err != nil {
		panic(err)
	}
	if err := cronet.LoadLibrary(filepath.Join(strings.TrimSpace(string(out)), library)); err != nil {
		panic(err)
	}
	os.Exit(m.Run())
}

// recordingDialer stands in for mihomo's dialer, which protects sockets
// from the VPN on Android; every Cronet socket must go through it.
type recordingDialer struct{ dials atomic.Int32 }

func (d *recordingDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	d.dials.Add(1)
	return dialer.NewDialer().DialContext(ctx, network, address)
}

func (d *recordingDialer) ListenPacket(ctx context.Context, network, address string, rAddrPort netip.AddrPort) (net.PacketConn, error) {
	return dialer.NewDialer().ListenPacket(ctx, network, address, rAddrPort)
}

func TestNaiveTunnelsThroughCronet(t *testing.T) {
	ca, server := testCertificates(t)
	proxyAddr, connects := startNaiveServer(t, server)
	target := startEchoServer(t)
	host, port, _ := net.SplitHostPort(proxyAddr)

	d := &recordingDialer{}
	proxy, err := adapter.ParseProxy(map[string]any{
		"type": "naive", "name": "naive", "server": host, "port": mustAtoi(t, port),
		"username": testUser, "password": testPassword, "sni": testSNI, "certificate": ca,
	}, adapter.WithDialerForAPI(d))
	if err != nil {
		t.Fatal(err)
	}
	defer proxy.Close()
	if proxy.Type() != C.Naive {
		t.Fatalf("type = %v, want Naive", proxy.Type())
	}
	if d.dials.Load() != 0 {
		t.Fatal("the Cronet engine connected before the node was used")
	}

	for i := 0; i < 2; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		conn, err := proxy.DialContext(ctx, metadataFor(t, target))
		cancel()
		if err != nil {
			t.Fatalf("dial %d: %v", i, err)
		}
		// More writes than Naive pads, so both framings are exercised.
		for j := 0; j < 12; j++ {
			message := strings.Repeat("x", j*100+1)
			if _, err := conn.Write([]byte(message)); err != nil {
				t.Fatal(err)
			}
			reply := make([]byte, len(message))
			_ = conn.SetReadDeadline(time.Now().Add(10 * time.Second))
			if _, err := io.ReadFull(conn, reply); err != nil {
				t.Fatalf("echo %d: %v", j, err)
			}
			if string(reply) != message {
				t.Fatalf("echo %d came back changed", j)
			}
		}
		_ = conn.Close()
	}
	if got := connects.Load(); got != 2 {
		t.Fatalf("server saw %d CONNECTs, want 2", got)
	}
	if d.dials.Load() == 0 {
		t.Fatal("Cronet bypassed mihomo's dialer")
	}
}

func TestNaiveRejectsWrongPassword(t *testing.T) {
	ca, server := testCertificates(t)
	proxyAddr, _ := startNaiveServer(t, server)
	host, port, _ := net.SplitHostPort(proxyAddr)
	proxy, err := adapter.ParseProxy(map[string]any{
		"type": "naive", "name": "naive", "server": host, "port": mustAtoi(t, port),
		"username": testUser, "password": "wrong", "sni": testSNI, "certificate": ca,
	})
	if err != nil {
		t.Fatal(err)
	}
	defer proxy.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if conn, err := proxy.DialContext(ctx, metadataFor(t, startEchoServer(t))); err == nil {
		conn.Close()
		t.Fatal("dial succeeded with a wrong password")
	}
}

func TestNaiveOptions(t *testing.T) {
	for _, bad := range []map[string]any{
		{"server": "example.org", "port": 0},
		{"server": "https://example.org", "port": 443},
		{"server": "example.org", "port": 443, "skip-cert-verify": true},
		{"server": "example.org", "port": 443, "client-fingerprint": "chrome"},
		{"server": "example.org", "port": 443, "udp": true},
		{"server": "example.org", "port": 443, "headers": map[string]any{"Host": "x"}},
		{"server": "example.org", "port": 443, "certificate": "-----BEGIN CERTIFICATE-----\nnope"},
	} {
		bad["type"], bad["name"] = "naive", "naive"
		if proxy, err := adapter.ParseProxy(bad); err == nil {
			proxy.Close()
			t.Errorf("accepted %v", bad)
		}
	}
	proxy, err := adapter.ParseProxy(map[string]any{
		"type": "naive", "name": "naive", "server": "example.org", "port": 443,
		"username": "u", "password": "p", "quic": true, "udp-over-tcp": true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if !proxy.SupportUDP() {
		t.Error("udp-over-tcp should enable UDP")
	}
	proxy.Close()
}

func mustAtoi(t *testing.T, s string) int {
	t.Helper()
	port, err := net.LookupPort("tcp", s)
	if err != nil {
		t.Fatal(err)
	}
	return port
}

func metadataFor(t *testing.T, address string) *C.Metadata {
	t.Helper()
	metadata := &C.Metadata{NetWork: C.TCP}
	if err := metadata.SetRemoteAddress(address); err != nil {
		t.Fatal(err)
	}
	return metadata
}

func testCertificates(t *testing.T) (string, tls.Certificate) {
	t.Helper()
	caKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	caTemplate := &x509.Certificate{
		SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "RoutaMi test CA"},
		NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(24 * time.Hour),
		IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign,
	}
	caDER, err := x509.CreateCertificate(rand.Reader, caTemplate, caTemplate, &caKey.PublicKey, caKey)
	if err != nil {
		t.Fatal(err)
	}
	caCert, _ := x509.ParseCertificate(caDER)
	key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	template := &x509.Certificate{
		SerialNumber: big.NewInt(2), Subject: pkix.Name{CommonName: testSNI}, DNSNames: []string{testSNI},
		NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(24 * time.Hour),
		KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	der, err := x509.CreateCertificate(rand.Reader, template, caCert, &key.PublicKey, caKey)
	if err != nil {
		t.Fatal(err)
	}
	ca := string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: caDER}))
	return ca, tls.Certificate{Certificate: [][]byte{der}, PrivateKey: key}
}

// startNaiveServer is a minimal NaiveProxy server: HTTP/2 CONNECT with Basic
// auth, and the padding framing on the first frames in each direction.
func startNaiveServer(t *testing.T, certificate tls.Certificate) (string, *atomic.Int32) {
	t.Helper()
	connects := &atomic.Int32{}
	wantAuth := "Basic " + base64.StdEncoding.EncodeToString([]byte(testUser+":"+testPassword))
	server := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodConnect || r.ProtoMajor != 2 {
			http.Error(w, "naive only", http.StatusBadRequest)
			return
		}
		if r.Header.Get("Proxy-Authorization") != wantAuth {
			w.WriteHeader(http.StatusProxyAuthRequired)
			return
		}
		upstream, err := net.Dial("tcp", r.Host)
		if err != nil {
			w.WriteHeader(http.StatusBadGateway)
			return
		}
		defer upstream.Close()
		connects.Add(1)
		w.Header().Set("Padding", strings.Repeat("~", 30))
		w.WriteHeader(http.StatusOK)
		flusher := w.(http.Flusher)
		flusher.Flush()
		var wg sync.WaitGroup
		wg.Add(1)
		go func() {
			defer wg.Done()
			_ = unpad(upstream, bufio.NewReader(r.Body))
			if tcp, ok := upstream.(*net.TCPConn); ok {
				_ = tcp.CloseWrite()
			}
		}()
		_ = pad(w, flusher, upstream)
		wg.Wait()
	})}
	listener, err := tls.Listen("tcp", "127.0.0.1:0", &tls.Config{
		Certificates: []tls.Certificate{certificate}, NextProtos: []string{"h2"},
	})
	if err != nil {
		t.Fatal(err)
	}
	go func() { _ = server.Serve(listener) }()
	t.Cleanup(func() { _ = server.Close() })
	return listener.Addr().String(), connects
}

const paddedFrames = 8

func unpad(dst io.Writer, src *bufio.Reader) error {
	header := make([]byte, 3)
	for i := 0; i < paddedFrames; i++ {
		if _, err := io.ReadFull(src, header); err != nil {
			return err
		}
		if _, err := io.CopyN(dst, src, int64(binary.BigEndian.Uint16(header))); err != nil {
			return err
		}
		if _, err := src.Discard(int(header[2])); err != nil {
			return err
		}
	}
	_, err := io.Copy(dst, src)
	return err
}

func pad(w io.Writer, flusher http.Flusher, src io.Reader) error {
	buffer := make([]byte, 16*1024)
	for frames := 0; ; frames++ {
		n, err := src.Read(buffer)
		if n > 0 {
			chunk := buffer[:n]
			if frames < paddedFrames {
				framed := binary.BigEndian.AppendUint16(nil, uint16(n))
				framed = append(framed, 16)
				framed = append(append(framed, chunk...), make([]byte, 16)...)
				chunk = framed
			}
			if _, werr := w.Write(chunk); werr != nil {
				return werr
			}
			flusher.Flush()
		}
		if err != nil {
			if errors.Is(err, io.EOF) {
				return nil
			}
			return err
		}
	}
}

func startEchoServer(t *testing.T) string {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = listener.Close() })
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go func() {
				defer conn.Close()
				_, _ = io.Copy(conn, conn)
			}()
		}
	}()
	return listener.Addr().String()
}
