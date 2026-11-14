package naive

import (
	"encoding/base64"
	"reflect"
	"testing"

	"github.com/metacubex/mihomo/common/convert"
)

func TestNaiveLinksBecomeNaiveProxies(t *testing.T) {
	links := "naive+https://user:p%40ss@naive.example.org#Home\n" +
		"naive+quic://u:p@203.0.113.5:8443?padding=true&extra-headers=X-A%3A%201%0D%0AX-B%3Atwo\n"
	proxies, err := convert.ConvertsV2Ray([]byte(base64.StdEncoding.EncodeToString([]byte(links))))
	if err != nil {
		t.Fatal(err)
	}
	want := []map[string]any{
		{
			"name": "Home", "type": "naive", "server": "naive.example.org", "port": "443",
			"username": "user", "password": "p@ss", "quic": false,
		},
		{
			"name": "203.0.113.5:8443", "type": "naive", "server": "203.0.113.5", "port": "8443",
			"username": "u", "password": "p", "quic": true,
			"headers": map[string]any{"X-A": "1", "X-B": "two"},
		},
	}
	if !reflect.DeepEqual(proxies, want) {
		t.Fatalf("got %#v\nwant %#v", proxies, want)
	}
}
