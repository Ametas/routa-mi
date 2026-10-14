package xray

import (
	"sync"

	applog "github.com/xtls/xray-core/app/log"
	"github.com/xtls/xray-core/common"
	"github.com/xtls/xray-core/common/log"
)

var (
	logMu sync.RWMutex
	logFn func(message string)
)

type forwarder struct{}

func (forwarder) Handle(msg log.Message) {
	logMu.RLock()
	fn := logFn
	logMu.RUnlock()
	if fn != nil {
		fn(msg.String())
	}
}

func init() {
	// Console output goes to the app's log screen instead of stdout.
	common.Must(applog.RegisterHandlerCreator(applog.LogType_Console,
		func(applog.LogType, applog.HandlerCreatorOptions) (log.Handler, error) {
			return forwarder{}, nil
		}))
}

// SetLogHandler receives Xray's console log lines; nil drops them.
func SetLogHandler(fn func(message string)) {
	logMu.Lock()
	logFn = fn
	logMu.Unlock()
}
