package xray

import (
	"context"
	"net"
	"net/http"
	"time"

	xnet "github.com/xtls/xray-core/common/net"
	"github.com/xtls/xray-core/common/session"
	"github.com/xtls/xray-core/core"
)

// TestDelay times a request to url through the outbound tag of the
// running instance, the way Xray's own observatory probes: the connection
// is forced to that outbound, so routing and the selected node do not
// matter and no second instance (with its global logger) is needed.
func TestDelay(ctx context.Context, tag, url string) (time.Duration, error) {
	mu.Lock()
	running := instance
	mu.Unlock()
	if running == nil {
		return 0, ErrNotRunning
	}
	transport := &http.Transport{
		Proxy:             nil,
		DisableKeepAlives: true,
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			dest, err := xnet.ParseDestination(network + ":" + addr)
			if err != nil {
				return nil, err
			}
			ctx = session.SetForcedOutboundTagToContext(ctx, tag)
			return core.Dial(ctx, running, dest)
		},
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{
		Transport: transport,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, err
	}
	start := time.Now()
	response, err := client.Do(request)
	if err != nil {
		return 0, err
	}
	_ = response.Body.Close()
	return time.Since(start), nil
}
