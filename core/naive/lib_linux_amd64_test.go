//go:build with_naive && with_purego && linux && amd64

package naive

// Pins the module that carries the libcronet.so the tests load.
import _ "github.com/sagernet/cronet-go/lib/linux_amd64"
