package xray

// Windows has no VpnService descriptor: Xray opens its own Wintun adapter.
func closeFd(int) {}
