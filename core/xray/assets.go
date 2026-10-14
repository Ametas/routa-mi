package xray

import (
	"os"
	"path/filepath"

	"github.com/xtls/xray-core/common/platform"
)

// UseGeoData points Xray at the geo databases mihomo already keeps: Xray
// looks for lower-case geoip.dat / geosite.dat in its asset directory, so
// dir gets symlinks to geoIP and geoSite instead of a second copy.
func UseGeoData(dir, geoIP, geoSite string) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	for name, target := range map[string]string{"geoip.dat": geoIP, "geosite.dat": geoSite} {
		link := filepath.Join(dir, name)
		if current, err := os.Readlink(link); err == nil && current == target {
			continue
		}
		_ = os.Remove(link)
		if err := os.Symlink(target, link); err != nil {
			return err
		}
	}
	return os.Setenv(platform.AssetLocation, dir)
}
