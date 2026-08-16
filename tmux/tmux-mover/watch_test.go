package main

import (
	"strings"
	"testing"
	"time"
)

func TestBuildPersistedAgentStatus(t *testing.T) {
	agents := map[string]AgentState{
		"%1": {Kind: AgentClaude, Status: AgentStatusWaiting},
		"%2": {Kind: AgentGemini, Status: AgentStatusIdle, Unseen: true, UnseenSince: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)},
	}
	paneByID := map[string]Pane{
		"%1": {ID: "%1", WindowID: "@1", SessionID: "$0", Path: "/a"},
		"%2": {ID: "%2", WindowID: "@1", SessionID: "$0", Path: "/b"},
	}
	sessionByID := map[string]string{"$0": "work"}
	windowByID := map[string]Window{"@1": {ID: "@1", Index: "0", Name: "editor"}}

	out := buildPersistedAgentStatus(agents, paneByID, sessionByID, windowByID)

	if out.Counts.Waiting != 1 || out.Counts.Idle != 1 || out.Counts.Unseen != 1 {
		t.Fatalf("unexpected counts: %+v", out.Counts)
	}
	byID := map[string]agentSnapshotJSON{}
	for _, p := range out.Panes {
		byID[p.PaneID] = p
	}
	if byID["%1"].Unseen {
		t.Fatalf("expected %%1 to not be unseen")
	}
	if !byID["%2"].Unseen || byID["%2"].UnseenSince != "2026-01-01T00:00:00Z" {
		t.Fatalf("expected %%2 to be unseen with a formatted timestamp, got %+v", byID["%2"])
	}
}

func TestTmuxJumpCommandSwitchesBeforeSelectingPane(t *testing.T) {
	cmd := tmuxJumpCommand(Pane{ID: "%1", WindowID: "@2", SessionID: "$3"})

	if !strings.Contains(cmd, "list-clients -F '#{client_name}'") {
		t.Fatalf("expected command to enumerate client names: %s", cmd)
	}
	if !strings.Contains(cmd, "switch-client -c \"$c\" -t '$3'") {
		t.Fatalf("expected command to switch clients to target session: %s", cmd)
	}
	if !strings.Contains(cmd, "select-window -t '@2'") {
		t.Fatalf("expected command to select target window: %s", cmd)
	}
	if !strings.Contains(cmd, "select-pane -t '%1'") {
		t.Fatalf("expected command to select target pane: %s", cmd)
	}
	if strings.Index(cmd, "switch-client") > strings.Index(cmd, "select-pane") {
		t.Fatalf("expected clients to switch before selecting pane: %s", cmd)
	}
}

func TestShouldNotifyAgentTransition(t *testing.T) {
	cases := []struct {
		name string
		prev AgentState
		next AgentState
		want bool
	}{
		{
			name: "fresh pane never notifies",
			prev: AgentState{Status: AgentStatusUnknown},
			next: AgentState{Status: AgentStatusIdle},
			want: false,
		},
		{
			name: "busy to idle, no background job: finished",
			prev: AgentState{Status: AgentStatusBusy},
			next: AgentState{Status: AgentStatusIdle},
			want: true,
		},
		{
			name: "busy to idle, but a background job is still running: notifies (free to type, not finished yet)",
			prev: AgentState{Status: AgentStatusBusy},
			next: AgentState{Status: AgentStatusIdle, HasBackgroundJob: true},
			want: true,
		},
		{
			name: "render stays idle the whole time, but the background job finishes: finished",
			prev: AgentState{Status: AgentStatusIdle, HasBackgroundJob: true},
			next: AgentState{Status: AgentStatusIdle, HasBackgroundJob: false},
			want: true,
		},
		{
			name: "waiting resolves straight into idle-with-job: notifies",
			prev: AgentState{Status: AgentStatusWaiting},
			next: AgentState{Status: AgentStatusIdle, HasBackgroundJob: true},
			want: true,
		},
		{
			name: "idle with a background job still running the whole time: no repeat notification",
			prev: AgentState{Status: AgentStatusIdle, HasBackgroundJob: true},
			next: AgentState{Status: AgentStatusIdle, HasBackgroundJob: true},
			want: false,
		},
		{
			name: "starts waiting for input: notifies regardless of background job",
			prev: AgentState{Status: AgentStatusBusy, HasBackgroundJob: true},
			next: AgentState{Status: AgentStatusWaiting, HasBackgroundJob: true},
			want: true,
		},
		{
			name: "already waiting: no repeat notification",
			prev: AgentState{Status: AgentStatusWaiting},
			next: AgentState{Status: AgentStatusWaiting},
			want: false,
		},
		{
			name: "idle to idle, never had a background job: no notification",
			prev: AgentState{Status: AgentStatusIdle},
			next: AgentState{Status: AgentStatusIdle},
			want: false,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := shouldNotifyAgentTransition(c.prev, c.next); got != c.want {
				t.Errorf("shouldNotifyAgentTransition(%+v, %+v) = %v, want %v", c.prev, c.next, got, c.want)
			}
		})
	}
}
