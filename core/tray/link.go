package main

import (
	"crypto/rand"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"strconv"
	"sync"
	"time"
)

// The IPC of RoutaMiCore.exe (core/server.go, lib/core/transport.dart):
// frames of a 4-byte little-endian length and JSON. The controller listens
// on 127.0.0.1 and the core dials it with "tcp:PORT:TOKEN" and sends the
// token as its first frame.

func writeFrame(w io.Writer, data []byte) error {
	frame := make([]byte, 4+len(data))
	binary.LittleEndian.PutUint32(frame, uint32(len(data)))
	copy(frame[4:], data)
	_, err := w.Write(frame)
	return err
}

func readFrame(r io.Reader) ([]byte, error) {
	var size [4]byte
	if _, err := io.ReadFull(r, size[:]); err != nil {
		return nil, err
	}
	data := make([]byte, binary.LittleEndian.Uint32(size[:]))
	_, err := io.ReadFull(r, data)
	return data, err
}

func randomToken() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}

// coreListener waits for one core to dial in.
type coreListener struct {
	ln    *net.TCPListener
	token string
}

func listenCore() (*coreListener, error) {
	ln, err := net.ListenTCP("tcp", &net.TCPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		return nil, err
	}
	return &coreListener{ln: ln, token: randomToken()}, nil
}

// address is the core's command-line argument.
func (c *coreListener) address() string {
	return "tcp:" + strconv.Itoa(c.ln.Addr().(*net.TCPAddr).Port) + ":" + c.token
}

func (c *coreListener) close() { _ = c.ln.Close() }

// accept returns the first connection that presents the token.
func (c *coreListener) accept(timeout time.Duration) (*coreLink, error) {
	defer c.close()
	deadline := time.Now().Add(timeout)
	for {
		_ = c.ln.SetDeadline(deadline)
		conn, err := c.ln.Accept()
		if err != nil {
			return nil, fmt.Errorf("the core did not connect: %w", err)
		}
		_ = conn.SetReadDeadline(deadline)
		token, err := readFrame(conn)
		if err == nil && string(token) == c.token {
			_ = conn.SetReadDeadline(time.Time{})
			return newCoreLink(conn), nil
		}
		_ = conn.Close()
	}
}

type coreResult struct {
	Id   string          `json:"id"`
	Data json.RawMessage `json:"data"`
	Code int             `json:"code"`
}

// coreLink is the tray's side of the IPC: calls by id, events dropped.
type coreLink struct {
	conn    net.Conn
	writeMu sync.Mutex
	mu      sync.Mutex
	pending map[string]chan coreResult
	next    int
	closed  chan struct{}
}

func newCoreLink(conn net.Conn) *coreLink {
	l := &coreLink{conn: conn, pending: map[string]chan coreResult{}, closed: make(chan struct{})}
	go l.read()
	return l
}

func (l *coreLink) read() {
	defer close(l.closed)
	for {
		data, err := readFrame(l.conn)
		if err != nil {
			return
		}
		var result coreResult
		if json.Unmarshal(data, &result) != nil || result.Id == "" {
			continue // events (logs, traffic) are the app's business
		}
		l.mu.Lock()
		ch := l.pending[result.Id]
		delete(l.pending, result.Id)
		l.mu.Unlock()
		if ch != nil {
			ch <- result
		}
	}
}

var errCoreGone = errors.New("the core is gone")

// call sends an action and waits for its result.
func (l *coreLink) call(method string, data any, timeout time.Duration) (json.RawMessage, error) {
	l.mu.Lock()
	l.next++
	id := method + "#tray" + strconv.Itoa(l.next)
	ch := make(chan coreResult, 1)
	l.pending[id] = ch
	l.mu.Unlock()
	defer func() {
		l.mu.Lock()
		delete(l.pending, id)
		l.mu.Unlock()
	}()

	frame, err := json.Marshal(map[string]any{"id": id, "method": method, "data": data})
	if err != nil {
		return nil, err
	}
	l.writeMu.Lock()
	err = writeFrame(l.conn, frame)
	l.writeMu.Unlock()
	if err != nil {
		return nil, err
	}
	return awaitResult(method, ch, l.closed, timeout)
}

// awaitResult waits for the answer to one call. A core may answer and hang
// up at once (handover): the reader delivers the answer before it marks the
// link closed, so an answer already waiting wins over the hang-up.
func awaitResult(method string, ch <-chan coreResult, closed <-chan struct{}, timeout time.Duration) (json.RawMessage, error) {
	answer := func(result coreResult) (json.RawMessage, error) {
		if result.Code != 0 {
			return nil, fmt.Errorf("%s: %s", method, result.Data)
		}
		return result.Data, nil
	}
	select {
	case result := <-ch:
		return answer(result)
	case <-closed:
		select {
		case result := <-ch:
			return answer(result)
		default:
			return nil, errCoreGone
		}
	case <-time.After(timeout):
		return nil, fmt.Errorf("%s: no answer in %s", method, timeout)
	}
}

// callText calls an action whose result is an error text ("" is success).
func (l *coreLink) callText(method string, data any, timeout time.Duration) error {
	raw, err := l.call(method, data, timeout)
	if err != nil {
		return err
	}
	var text string
	if json.Unmarshal(raw, &text) == nil && text != "" {
		return fmt.Errorf("%s: %s", method, text)
	}
	return nil
}

func (l *coreLink) close() { _ = l.conn.Close() }

func (l *coreLink) alive() bool {
	select {
	case <-l.closed:
		return false
	default:
		return true
	}
}
