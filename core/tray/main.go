// Command tray is RoutaMiTray.exe, RoutaMi's lite mode on Windows: the app
// unloads its window and Flutter engine and leaves the core to this small
// process with a notification-area icon (start/stop, restart the core,
// open RoutaMi, exit). Reopening RoutaMi takes the core back.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
)

func main() {
	var snap snapshot
	if err := json.NewDecoder(io.LimitReader(os.Stdin, 1<<20)).Decode(&snap); err != nil {
		fmt.Fprintln(os.Stderr, "lite snapshot:", err)
		os.Exit(2)
	}
	if snap.State == "" || snap.Core == "" {
		fmt.Fprintln(os.Stderr, "lite snapshot: state and core are required")
		os.Exit(2)
	}
	if f, err := os.Create(filepath.Join(filepath.Dir(snap.State), "lite.log")); err == nil {
		log.SetOutput(f)
		defer f.Close()
	}
	// The app reads only the first line; it may exit right after.
	out := func(line string) { fmt.Fprintln(os.Stdout, line) }
	if err := run(snap, newPlatform(), out); err != nil {
		log.Printf("lite mode: %v", err)
		os.Exit(1)
	}
}
