//go:build !windows

package main

import (
	"errors"
	"time"
)

// Off Windows the tray has no UI; it runs headless for development.
type headless struct{ done chan struct{} }

func newPlatform() platform { return &headless{done: make(chan struct{})} }

func (h *headless) runUI(t *liteTray)           { <-h.done }
func (h *headless) quitUI()                     { close(h.done) }
func (h *headless) updateUI(bool)               {}
func (h *headless) stopHelperCore() error       { return nil }
func (h *headless) waitExit(int, time.Duration) {}
func (h *headless) openApp(string) error        { return errors.ErrUnsupported }
func (h *headless) setSystemProxy(bool, int, []string) error {
	return errors.ErrUnsupported
}
func (h *headless) startCore(string, string, bool) error {
	return errors.ErrUnsupported
}
