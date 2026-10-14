package xray

import (
	"sync"
	"syscall"

	"github.com/xtls/xray-core/transport/internet"
)

var (
	protectOnce sync.Once
	protectMu   sync.RWMutex
	protectFn   func(fd int) bool
)

// SetProtect routes every socket Xray dials through fn before use, so the
// VpnService can exclude it from the tunnel (VpnService.protect). Pass nil
// to stop protecting.
func SetProtect(fn func(fd int) bool) {
	protectMu.Lock()
	protectFn = fn
	protectMu.Unlock()
	protectOnce.Do(func() {
		// Controllers cannot be removed, so one forwards to the current fn.
		_ = internet.RegisterDialerController(func(_, _ string, conn syscall.RawConn) error {
			protectMu.RLock()
			fn := protectFn
			protectMu.RUnlock()
			if fn == nil {
				return nil
			}
			return conn.Control(func(fd uintptr) { fn(int(fd)) })
		})
	})
}
