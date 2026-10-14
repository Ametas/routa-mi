package main

import (
	"encoding/base64"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func validateBuf(t *testing.T, content string) error {
	t.Helper()
	path := filepath.Join(t.TempDir(), "profile.yaml")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return validateConfigFile(path)
}

func TestXrayJSONSubscriptionIsExplained(t *testing.T) {
	err := validateBuf(t, `[{"outbounds":[{"protocol":"vless"}]}]`)
	if err == nil || !strings.Contains(err.Error(), "Xray JSON") {
		t.Fatalf("got %v", err)
	}
	if !strings.Contains(err.Error(), "cannot unmarshal") {
		t.Fatalf("the core error should stay attached: %v", err)
	}
}

func TestShareLinkSubscriptionIsExplained(t *testing.T) {
	links := "vless://id@example.com:443?security=reality#JP\nvmess://abc"
	for _, content := range []string{links, base64.StdEncoding.EncodeToString([]byte(links))} {
		err := validateBuf(t, content)
		if err == nil || !strings.Contains(err.Error(), "share links") {
			t.Fatalf("got %v", err)
		}
	}
}

func TestOtherErrorsAreUnchanged(t *testing.T) {
	cause := errors.New("boom")
	if got := explainSubscriptionFormat([]byte("just some text"), cause); got != cause {
		t.Fatalf("got %v", got)
	}
	if err := validateBuf(t, "mixed-port: 7890\nproxies: []\n"); err != nil {
		t.Fatalf("a Clash config must still validate: %v", err)
	}
}
