package main

import (
	"errors"
	"testing"
	"time"
)

// A core that answers and hangs up at once (handover) must still be heard:
// with the answer and the hang-up both waiting, the answer wins every time.
func TestAnAnswerWinsOverTheHangUpAfterIt(t *testing.T) {
	closed := make(chan struct{})
	close(closed)
	for run := 0; run < 200; run++ {
		ch := make(chan coreResult, 1)
		ch <- coreResult{Id: "handover#tray1", Data: []byte(`""`)}
		if _, err := awaitResult("handover", ch, closed, time.Second); err != nil {
			t.Fatalf("run %d: %v", run, err)
		}
	}
	if _, err := awaitResult("handover", make(chan coreResult, 1), closed, time.Second); !errors.Is(err, errCoreGone) {
		t.Fatalf("a hang-up without an answer gave %v", err)
	}
}
