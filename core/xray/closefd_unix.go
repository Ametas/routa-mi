//go:build !windows

package xray

import "syscall"

// closeFd closes the VpnService TUN descriptor Xray ran on.
func closeFd(fd int) {
	if fd > 0 {
		_ = syscall.Close(fd)
	}
}
