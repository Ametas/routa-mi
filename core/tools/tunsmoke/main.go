// Command tunsmoke plays the RoutaMi app against RoutaMiCore.exe on a CI
// Windows runner (an administrator): it starts the core over the loopback
// transport, loads a direct-mode config with TUN on, and checks that the
// Wintun adapter comes up and carries traffic, once for every TUN stack the
// app offers.
package main

import (
	"encoding/binary"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"
)

// stacks the app offers (lib/enum/enum.dart TunStack); mixed is its default.
var stacks = []string{"mixed", "gvisor", "system", "mips"}

const config = `mixed-port: 7899
mode: direct
log-level: info
ipv6: false
dns:
  enable: true
  ipv6: false
  nameserver: [1.1.1.1, 8.8.8.8]
tun:
  enable: true
  device: RoutaMi
  stack: %s
  auto-route: true
  auto-detect-interface: true
  dns-hijack: ["any:53"]
`

type result struct {
	ID   string          `json:"id"`
	Data json.RawMessage `json:"data"`
}

type session struct {
	conn net.Conn
	next int
}

func writeFrame(w io.Writer, data []byte) error {
	frame := binary.LittleEndian.AppendUint32(nil, uint32(len(data)))
	_, err := w.Write(append(frame, data...))
	return err
}

func readFrame(r io.Reader) ([]byte, error) {
	header := make([]byte, 4)
	if _, err := io.ReadFull(r, header); err != nil {
		return nil, err
	}
	data := make([]byte, binary.LittleEndian.Uint32(header))
	_, err := io.ReadFull(r, data)
	return data, err
}

// call sends an action and waits for its result, skipping core events.
func (s *session) call(method string, data any) (json.RawMessage, error) {
	s.next++
	id := method + "#" + strconv.Itoa(s.next)
	payload, _ := json.Marshal(map[string]any{"id": id, "method": method, "data": data})
	if err := writeFrame(s.conn, payload); err != nil {
		return nil, err
	}
	_ = s.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	for {
		frame, err := readFrame(s.conn)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", method, err)
		}
		var r result
		if json.Unmarshal(frame, &r) == nil && r.ID == id {
			return r.Data, nil
		}
	}
}

func main() {
	corePath := flag.String("core", "", "RoutaMiCore.exe")
	flag.Parse()
	var failed []string
	for _, stack := range stacks {
		log.Printf("--- stack %s", stack)
		if err := run(*corePath, stack); err != nil {
			log.Printf("stack %s FAILED: %v", stack, err)
			failed = append(failed, stack)
		} else {
			log.Printf("stack %s passed", stack)
		}
		waitAdapterGone()
	}
	if len(failed) > 0 {
		log.Fatalf("TUN failed with stacks %v", failed)
	}
	log.Print("TUN smoke test passed")
}

// waitAdapterGone lets the stopped core remove its adapter before the next
// stack creates one with the same name.
func waitAdapterGone() {
	deadline := time.Now().Add(15 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := net.InterfaceByName("RoutaMi"); err != nil {
			return
		}
		time.Sleep(500 * time.Millisecond)
	}
}

func run(corePath, stack string) error {
	home, err := os.MkdirTemp("", "routami-tun")
	if err != nil {
		return err
	}
	yaml := fmt.Sprintf(config, stack)
	if err := os.WriteFile(filepath.Join(home, "config.yaml"), []byte(yaml), 0o644); err != nil {
		return err
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return err
	}
	defer listener.Close()
	port := listener.Addr().(*net.TCPAddr).Port
	core := exec.Command(corePath, fmt.Sprintf("tcp:%d:smoke", port))
	core.Stderr = os.Stderr
	if err := core.Start(); err != nil {
		return err
	}
	defer func() {
		_ = core.Process.Kill()
		_ = core.Wait()
	}()
	conn, err := listener.Accept()
	if err != nil {
		return err
	}
	if token, err := readFrame(conn); err != nil || string(token) != "smoke" {
		return fmt.Errorf("bad handshake %q: %v", token, err)
	}
	s := &session{conn: conn}

	params, _ := json.Marshal(map[string]any{"home-dir": home, "version": 10})
	if data, err := s.call("initClash", string(params)); err != nil || string(data) != "true" {
		return fmt.Errorf("initClash = %s, %v", data, err)
	}
	if data, err := s.call("setupConfig", "{}"); err != nil || string(data) != `""` {
		return fmt.Errorf("setupConfig = %s, %v", data, err)
	}
	if data, err := s.call("startListener", nil); err != nil || string(data) != "true" {
		return fmt.Errorf("startListener = %s, %v", data, err)
	}

	deadline := time.Now().Add(20 * time.Second)
	for {
		if _, err := net.InterfaceByName("RoutaMi"); err == nil {
			break
		}
		if time.Now().After(deadline) {
			return errors.New("the RoutaMi Wintun adapter did not come up")
		}
		time.Sleep(500 * time.Millisecond)
	}
	log.Print("Wintun adapter RoutaMi is up")
	time.Sleep(3 * time.Second) // routes settle

	client := &http.Client{Timeout: 15 * time.Second}
	response, err := client.Get("http://www.msftconnecttest.com/connecttest.txt")
	if err != nil {
		return fmt.Errorf("request through TUN: %w", err)
	}
	body, _ := io.ReadAll(response.Body)
	response.Body.Close()
	log.Printf("through TUN: %s %q", response.Status, body)

	raw, err := s.call("getTotalTraffic", false)
	if err != nil {
		return err
	}
	var text string
	_ = json.Unmarshal(raw, &text)
	var traffic struct {
		Up   int64 `json:"up"`
		Down int64 `json:"down"`
	}
	if err := json.Unmarshal([]byte(text), &traffic); err != nil {
		return fmt.Errorf("traffic %s: %w", raw, err)
	}
	if traffic.Down == 0 {
		return fmt.Errorf("the core counted no traffic (%s): the request bypassed TUN", text)
	}
	log.Printf("core counted %d B up, %d B down", traffic.Up, traffic.Down)
	_, _ = s.call("stopListener", nil)
	return nil
}
