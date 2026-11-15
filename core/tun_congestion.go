package main

// tunCongestionController is the mips stack's TCP congestion control from
// the applied config ("" lets mipstack pick its default, cubic). The Android
// TUN gets its stack from VpnService and this from the profile patch.
// The caller holds runLock.
func tunCongestionController() string {
	if currentConfig == nil || currentConfig.General == nil {
		return ""
	}
	return currentConfig.General.Tun.CongestionController
}
