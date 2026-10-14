package xray

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/xtls/xray-core/common/platform"
)

func TestUseGeoDataLinksMihomoFiles(t *testing.T) {
	home := t.TempDir()
	geoIP := filepath.Join(home, "GeoIP.dat")
	geoSite := filepath.Join(home, "GeoSite.dat")
	for _, path := range []string{geoIP, geoSite} {
		if err := os.WriteFile(path, []byte(filepath.Base(path)), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	dir := filepath.Join(home, "xray-assets")
	for range 2 { // idempotent
		if err := UseGeoData(dir, geoIP, geoSite); err != nil {
			t.Fatal(err)
		}
	}
	for name, want := range map[string]string{"geoip.dat": "GeoIP.dat", "geosite.dat": "GeoSite.dat"} {
		got, err := os.ReadFile(platform.GetAssetLocation(name))
		if err != nil || string(got) != want {
			t.Fatalf("%s -> %q, %v", name, got, err)
		}
	}
}
