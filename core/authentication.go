package main

import (
	"strings"

	"github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/component/auth"
	"github.com/metacubex/mihomo/config"
	authStore "github.com/metacubex/mihomo/listener/auth"
)

// applyAuthentication installs the app-owned credentials of the local
// http/socks/mixed listeners. RoutaMi always owns them: an empty list turns
// authentication off, a non-empty one also drops every skip-auth prefix,
// because a loopback exemption would let any app on the device use the
// tunnel without the credentials.
func applyAuthentication(cfg *config.Config, authentication []string) {
	users := make([]auth.AuthUser, 0, len(authentication))
	for _, line := range authentication {
		if user, pass, found := strings.Cut(line, ":"); found {
			users = append(users, auth.AuthUser{User: user, Pass: pass})
		}
	}
	if cfg != nil {
		cfg.Users = users
		if cfg.General != nil {
			cfg.General.Authentication = authentication
		}
	}
	authStore.Default.SetAuthenticator(auth.NewAuthenticator(users))
	if len(users) > 0 {
		if cfg != nil && cfg.General != nil {
			cfg.General.SkipAuthPrefixes = nil
		}
		inbound.SetSkipAuthPrefixes(nil)
	}
}
