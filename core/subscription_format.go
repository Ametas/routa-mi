package main

import (
	"encoding/base64"
	"fmt"
	"strings"

	"gopkg.in/yaml.v3"
)

// explainSubscriptionFormat turns the core's YAML error for a profile that
// is not a Clash/mihomo config into something a user can act on. Panels
// pick the format by User-Agent and fall back to share links or Xray JSON.
func explainSubscriptionFormat(buf []byte, cause error) error {
	var node yaml.Node
	if err := yaml.Unmarshal(buf, &node); err != nil || len(node.Content) == 0 {
		return cause
	}
	switch node.Content[0].Kind {
	case yaml.SequenceNode:
		return fmt.Errorf("the subscription returned a list (probably Xray JSON), not a Clash/mihomo config; the server picks the format by User-Agent — set UA to \"mihomo\" or \"clash-verge\" in Basic settings and update the profile (%w)", cause)
	case yaml.ScalarNode:
		if looksLikeShareLinks(node.Content[0].Value) {
			return fmt.Errorf("the subscription returned share links (vless://, vmess://…), not a Clash/mihomo config; the server picks the format by User-Agent — set UA to \"mihomo\" or \"clash-verge\" in Basic settings and update the profile (%w)", cause)
		}
	}
	return cause
}

func looksLikeShareLinks(text string) bool {
	text = strings.TrimSpace(text)
	if decoded, err := base64.StdEncoding.DecodeString(text); err == nil {
		text = string(decoded)
	} else if decoded, err := base64.RawStdEncoding.DecodeString(text); err == nil {
		text = string(decoded)
	}
	return strings.Contains(text, "://")
}
