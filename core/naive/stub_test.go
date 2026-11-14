//go:build !with_naive

package naive

import (
	"strings"
	"testing"

	"github.com/metacubex/mihomo/adapter"
)

// Builds without Cronet must reject Naive nodes with a clear reason instead
// of dropping them silently.
func TestNaiveNeedsTheBuildTag(t *testing.T) {
	_, err := adapter.ParseProxy(map[string]any{"type": "naive", "name": "n", "server": "example.org", "port": 443})
	if err == nil || !strings.Contains(err.Error(), "with_naive") {
		t.Fatalf("got %v, want an error naming the with_naive tag", err)
	}
}
