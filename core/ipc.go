//go:build !cgo

package main

import (
	"errors"
	"io"
	"net"
	"strings"
)

// dialCore connects the core process to the app. "tcp:PORT:TOKEN" is the
// loopback transport of the Windows app: the app listens on 127.0.0.1 and
// accepts only a connection whose first frame is its random token. Other
// arguments keep the platform transports in dial_*.go.
func dialCore(arg string) (io.ReadWriteCloser, error) {
	rest, ok := strings.CutPrefix(arg, "tcp:")
	if !ok {
		return dial(arg)
	}
	port, token, ok := strings.Cut(rest, ":")
	if !ok || port == "" || token == "" {
		return nil, errors.New("ipc: want tcp:PORT:TOKEN")
	}
	conn, err := net.Dial("tcp", net.JoinHostPort("127.0.0.1", port))
	if err != nil {
		return nil, err
	}
	if err := writeFrame(conn, []byte(token)); err != nil {
		_ = conn.Close()
		return nil, err
	}
	return conn, nil
}
