//go:build !cgo

package main

import (
	"net"
	"strconv"
	"testing"
)

func TestDialCoreSendsTheTokenFirst(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	port := strconv.Itoa(listener.Addr().(*net.TCPAddr).Port)
	accepted := make(chan []byte, 1)
	go func() {
		conn, err := listener.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		token, _ := readFrame(conn)
		accepted <- token
	}()

	conn, err := dialCore("tcp:" + port + ":s3cret")
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	if token := <-accepted; string(token) != "s3cret" {
		t.Fatalf("first frame = %q, want the token", token)
	}

	for _, bad := range []string{"tcp:", "tcp:" + port, "tcp::token", "tcp:" + port + ":"} {
		if _, err := dialCore(bad); err == nil {
			t.Errorf("%q dialed", bad)
		}
	}
}
