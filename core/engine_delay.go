package main

import (
	"context"
	"encoding/json"
	"time"

	"core/xray"
)

// xrayTestDelay answers asyncTestDelay while Xray runs. The app sends the
// node's outbound tag as the proxy name and maps the result back.
func xrayTestDelay(paramsString string, fn func(string)) {
	var params TestDelayParams
	if err := json.Unmarshal([]byte(paramsString), &params); err != nil {
		fn("")
		return
	}
	testURL := params.TestUrl
	if testURL == "" {
		testURL = defaultTestURL
	}
	timeout := time.Duration(params.Timeout) * time.Millisecond
	if timeout <= 0 {
		timeout = 5 * time.Second
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	result := Delay{Name: params.ProxyName, Url: testURL, Value: -1}
	if delay, err := xray.TestDelay(ctx, params.ProxyName, testURL); err == nil && delay > 0 {
		result.Value = int32(delay.Milliseconds())
	}
	data, _ := json.Marshal(result)
	fn(string(data))
}
