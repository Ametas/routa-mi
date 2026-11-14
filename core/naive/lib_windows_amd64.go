//go:build with_naive && windows && amd64

package naive

// Pins the module that carries libcronet.dll; the build tool ships the DLL
// next to RoutaMiCore.exe, where Cronet's purego loader looks first.
import _ "github.com/sagernet/cronet-go/lib/windows_amd64"
