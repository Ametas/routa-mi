// Command helper is RoutaMiHelperService, the Windows service that runs the
// RoutaMi core as LocalSystem so the core can create the Wintun adapter and
// routes for TUN. The app registers it once through UAC (lib/common/system.dart)
// and then asks it over 127.0.0.1 to start and stop the core.
//
// Only the RoutaMi.exe installed next to the helper may call it, and it only
// starts the RoutaMiCore.exe next to it whose SHA-256 matches the build.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const (
	listenAddr  = "127.0.0.1:47990" // helperPort in lib/common/constant.dart
	appExeName  = "RoutaMi.exe"
	coreExeName = "RoutaMiCore.exe"
	maxLogLines = 100
)

// coreSHA256 is set at build time (-X main.coreSHA256=...) to the hash of the
// RoutaMiCore.exe shipped with this helper.
var coreSHA256 string

type startParams struct {
	Path string `json:"path"`
	Arg  string `json:"arg"`
}

// process is the running core as the helper sees it.
type process interface {
	Kill() error
	Wait() error
}

type helper struct {
	dir string // directory of the helper, the app and the core
	// callerPath returns the executable of the process behind a request.
	callerPath func(r *http.Request) (string, error)
	// spawn starts the core; its stderr lines go to log.
	spawn func(path, arg string, log func(string)) (process, error)

	file io.Writer // optional copy of the log

	mu   sync.Mutex
	core process
	logs []string
}

func sameFile(a, b string) bool {
	return strings.EqualFold(filepath.Clean(a), filepath.Clean(b))
}

func fileSHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func (h *helper) log(line string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(h.logs) == maxLogLines {
		h.logs = h.logs[1:]
	}
	h.logs = append(h.logs, line)
	if h.file != nil {
		fmt.Fprintf(h.file, "%s %s\n", time.Now().Format(time.RFC3339), line)
	}
}

func (h *helper) authorize(r *http.Request) error {
	caller, err := h.callerPath(r)
	if err != nil {
		return fmt.Errorf("unknown caller: %w", err)
	}
	if !sameFile(caller, filepath.Join(h.dir, appExeName)) {
		return fmt.Errorf("caller %s is not %s next to the helper", caller, appExeName)
	}
	return nil
}

func (h *helper) start(params startParams) error {
	corePath := filepath.Join(h.dir, coreExeName)
	if !sameFile(params.Path, corePath) {
		return fmt.Errorf("only %s can be started", corePath)
	}
	if coreSHA256 == "" {
		return errors.New("helper was built without the core hash")
	}
	sum, err := fileSHA256(corePath)
	if err != nil {
		return err
	}
	if sum != coreSHA256 {
		return fmt.Errorf("core hash %s does not match %s", sum, coreSHA256)
	}
	h.stop()
	h.log("starting the core")
	core, err := h.spawn(corePath, params.Arg, h.log)
	if err != nil {
		return err
	}
	h.mu.Lock()
	h.core = core
	h.mu.Unlock()
	return nil
}

func (h *helper) stop() {
	h.mu.Lock()
	core := h.core
	h.core = nil
	h.mu.Unlock()
	if core != nil {
		_ = core.Kill()
		_ = core.Wait()
	}
}

// handler serves the API the app calls (lib/common/request.dart). Errors
// come back as a non-empty plain-text body; an empty body means success.
func (h *helper) handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /ping", func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, coreSHA256)
	})
	mux.HandleFunc("POST /start", func(w http.ResponseWriter, r *http.Request) {
		if err := h.authorize(r); err != nil {
			http.Error(w, err.Error(), http.StatusForbidden)
			return
		}
		var params startParams
		if err := json.NewDecoder(io.LimitReader(r.Body, 64<<10)).Decode(&params); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if err := h.start(params); err != nil {
			h.log(err.Error())
			_, _ = io.WriteString(w, err.Error())
		}
	})
	mux.HandleFunc("POST /stop", func(w http.ResponseWriter, r *http.Request) {
		if err := h.authorize(r); err != nil {
			http.Error(w, err.Error(), http.StatusForbidden)
			return
		}
		h.stop()
	})
	mux.HandleFunc("GET /logs", func(w http.ResponseWriter, r *http.Request) {
		if err := h.authorize(r); err != nil {
			http.Error(w, err.Error(), http.StatusForbidden)
			return
		}
		h.mu.Lock()
		defer h.mu.Unlock()
		_, _ = io.WriteString(w, strings.Join(h.logs, "\n"))
	})
	return mux
}
