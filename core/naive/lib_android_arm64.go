//go:build with_naive && android && arm64 && !with_purego

package naive

// Statically links Chromium's network stack (prebuilt by SagerNet/cronet-go).
import _ "github.com/sagernet/cronet-go/lib/android_arm64"
