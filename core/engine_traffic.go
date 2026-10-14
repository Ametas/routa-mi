package main

import (
	"encoding/json"
	"sync"
	"time"

	"core/xray"
)

// Dashboard traffic while Xray runs, in the shape of mihomo's snapshot:
// totals from Xray's outbound counters, speed from the change since the
// previous poll. "Proxy only" counts the nodes under the selection
// balancer.
var (
	xrayTrafficLock sync.Mutex
	xrayProxyTags   map[string]bool
	xrayLastPoll    = map[bool]xrayTrafficSample{}
)

type xrayTrafficSample struct {
	at       time.Time
	up, down int64
}

// setXrayProxyTags reads the balancer's nodes from the running config.
func setXrayProxyTags(buf []byte, balancer string) {
	var config struct {
		Routing struct {
			Balancers []struct {
				Tag      string   `json:"tag"`
				Selector []string `json:"selector"`
			} `json:"balancers"`
		} `json:"routing"`
	}
	tags := map[string]bool{}
	if json.Unmarshal(buf, &config) == nil {
		for _, b := range config.Routing.Balancers {
			if b.Tag == balancer {
				for _, tag := range b.Selector {
					tags[tag] = true
				}
			}
		}
	}
	xrayTrafficLock.Lock()
	xrayProxyTags = tags
	xrayLastPoll = map[bool]xrayTrafficSample{}
	xrayTrafficLock.Unlock()
}

func xrayTrafficSnapshot(onlyProxy bool) string {
	xrayTrafficLock.Lock()
	defer xrayTrafficLock.Unlock()
	var include func(string) bool
	if onlyProxy {
		tags := xrayProxyTags
		include = func(tag string) bool { return tags[tag] }
	}
	totalUp, totalDown, err := xray.Traffic(include)
	if err != nil {
		totalUp, totalDown = 0, 0
	}
	now := time.Now()
	var up, down int64
	if last, ok := xrayLastPoll[onlyProxy]; ok {
		if seconds := now.Sub(last.at).Seconds(); seconds > 0 {
			up = max(0, int64(float64(totalUp-last.up)/seconds))
			down = max(0, int64(float64(totalDown-last.down)/seconds))
		}
	}
	xrayLastPoll[onlyProxy] = xrayTrafficSample{at: now, up: totalUp, down: totalDown}
	data, _ := json.Marshal(map[string]int64{
		"up":        up,
		"down":      down,
		"totalUp":   totalUp,
		"totalDown": totalDown,
	})
	return string(data)
}
