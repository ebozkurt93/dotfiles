package main

import "testing"

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
			name: "busy to idle, but a background job is still running: not finished yet",
			prev: AgentState{Status: AgentStatusBusy},
			next: AgentState{Status: AgentStatusIdle, HasBackgroundJob: true},
			want: false,
		},
		{
			name: "render stays idle the whole time, but the background job finishes: finished",
			prev: AgentState{Status: AgentStatusIdle, HasBackgroundJob: true},
			next: AgentState{Status: AgentStatusIdle, HasBackgroundJob: false},
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
