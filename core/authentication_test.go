package main

import (
	"net/netip"
	"testing"

	"github.com/metacubex/mihomo/adapter/inbound"
	"github.com/metacubex/mihomo/config"
	authStore "github.com/metacubex/mihomo/listener/auth"
)

func TestUpdateConfigAppliesAuthenticationAndDropsLoopbackExemption(t *testing.T) {
	previous, running := currentConfig, isRunning
	t.Cleanup(func() {
		currentConfig, isRunning = previous, running
		authStore.Default.SetAuthenticator(nil)
		inbound.SetSkipAuthPrefixes(nil)
	})
	currentConfig = &config.Config{General: &config.General{}, Controller: &config.Controller{}}
	isRunning = false // No real sockets in this unit test.
	currentConfig.General.SkipAuthPrefixes = []netip.Prefix{
		netip.MustParsePrefix("127.0.0.1/32"),
	}
	inbound.SetSkipAuthPrefixes(currentConfig.General.SkipAuthPrefixes)

	users := []string{"routami:secret:with:colons"}
	if err := updateConfig(&UpdateParams{Authentication: &users}); err != nil {
		t.Fatalf("updateConfig error: %v", err)
	}
	authenticator := authStore.Default.Authenticator()
	if authenticator == nil || !authenticator.Verify("routami", "secret:with:colons") {
		t.Fatal("authenticator missing or rejecting the configured credentials")
	}
	if authenticator.Verify("routami", "wrong") {
		t.Fatal("authenticator accepted a wrong password")
	}
	if inbound.SkipAuthRemoteAddress("127.0.0.1:1234") {
		t.Fatal("loopback stayed exempt; local apps could bypass the credentials")
	}
	if len(currentConfig.General.Authentication) != 1 || len(currentConfig.Users) != 1 {
		t.Fatal("credentials not recorded in the running config")
	}

	empty := []string{}
	if err := updateConfig(&UpdateParams{Authentication: &empty}); err != nil {
		t.Fatalf("updateConfig error: %v", err)
	}
	if authStore.Default.Authenticator() != nil {
		t.Fatal("authenticator survived an empty authentication list")
	}
}

func TestUpdateConfigWithoutAuthenticationKeepsCredentials(t *testing.T) {
	previous, running := currentConfig, isRunning
	t.Cleanup(func() {
		currentConfig, isRunning = previous, running
		authStore.Default.SetAuthenticator(nil)
	})
	currentConfig = &config.Config{General: &config.General{}, Controller: &config.Controller{}}
	isRunning = false
	users := []string{"a:b"}
	if err := updateConfig(&UpdateParams{Authentication: &users}); err != nil {
		t.Fatal(err)
	}
	allowLan := true
	if err := updateConfig(&UpdateParams{AllowLan: &allowLan}); err != nil {
		t.Fatal(err)
	}
	if authStore.Default.Authenticator() == nil {
		t.Fatal("an unrelated hot update dropped the credentials")
	}
}
