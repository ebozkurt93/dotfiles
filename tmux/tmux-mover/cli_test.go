package main

import (
	"bytes"
	"encoding/json"
	"os"
	"testing"
)

func TestFormatAgentStatusPlain(t *testing.T) {
	cases := []struct {
		waiting, busy, idle int
		want                string
	}{
		{0, 0, 0, "No AI sessions detected."},
		{1, 0, 0, "1 waiting for input"},
		{0, 2, 0, "2 working"},
		{0, 0, 3, "3 idle"},
		{1, 2, 3, "1 waiting for input, 2 working, 3 idle"},
	}
	for _, c := range cases {
		if got := formatAgentStatusPlain(c.waiting, c.busy, c.idle); got != c.want {
			t.Errorf("formatAgentStatusPlain(%d,%d,%d) = %q, want %q", c.waiting, c.busy, c.idle, got, c.want)
		}
	}
}

func TestPrintAgentStatusJSONShape(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", Name: "w0"}},
	}
	snapshots := []agentSnapshot{
		{
			pane:   Pane{ID: "%1", WindowID: "@1", SessionID: "$0", Title: "✳ Fix the bug", Path: "~/proj"},
			kind:   AgentClaude,
			status: AgentStatusWaiting,
		},
	}

	var buf bytes.Buffer
	orig := os.Stdout
	r, w, _ := os.Pipe()
	os.Stdout = w
	t.Cleanup(func() { os.Stdout = orig })

	err := printAgentStatusJSON(snapshots, state)
	w.Close()
	os.Stdout = orig
	if err != nil {
		t.Fatalf("printAgentStatusJSON error: %v", err)
	}
	buf.ReadFrom(r)

	var got agentStatusJSON
	if err := json.Unmarshal(buf.Bytes(), &got); err != nil {
		t.Fatalf("output is not valid JSON: %v\n%s", err, buf.String())
	}
	if len(got.Panes) != 1 {
		t.Fatalf("expected 1 pane, got %d", len(got.Panes))
	}
	p := got.Panes[0]
	if p.PaneID != "%1" || p.Kind != "claude" || p.Status != "waiting" || p.Task != "Fix the bug" || p.Session != "work" {
		t.Fatalf("unexpected pane JSON: %+v", p)
	}
	if got.Counts.Waiting != 1 {
		t.Fatalf("expected waiting count 1, got %d", got.Counts.Waiting)
	}
}

func TestCountByStatus(t *testing.T) {
	snapshots := []agentSnapshot{
		{status: AgentStatusWaiting},
		{status: AgentStatusBusy},
		{status: AgentStatusBusy},
		{status: AgentStatusIdle},
		{status: AgentStatusUnknown},
	}
	waiting, busy, idle := countByStatus(snapshots)
	if waiting != 1 || busy != 2 || idle != 2 {
		t.Fatalf("expected 1,2,2 got %d,%d,%d", waiting, busy, idle)
	}
}
