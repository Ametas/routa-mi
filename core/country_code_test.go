package main

import (
	"testing"
	"time"
)

// mihomo exits the process when the MMDB cannot load, so a lookup before
// initClash (no home directory yet) must not reach it.
func TestCountryCodeBeforeInitDoesNotLoadMMDB(t *testing.T) {
	runLock.Lock()
	wasInit := isInit
	isInit = false
	runLock.Unlock()
	t.Cleanup(func() {
		runLock.Lock()
		isInit = wasInit
		runLock.Unlock()
	})

	code := make(chan string, 1)
	handleGetCountryCode("8.8.8.8", func(value string) { code <- value })
	select {
	case value := <-code:
		if value != "" {
			t.Fatalf("country code = %q, want empty before init", value)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("no answer")
	}
}
