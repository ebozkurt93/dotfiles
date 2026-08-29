package main

import (
	"strings"
	"testing"
	"time"
)

func TestParseNotificationConfig(t *testing.T) {
	cases := []struct {
		name       string
		value      string
		wantSound  bool
		wantBanner bool
		wantMode   string
		wantOK     bool
	}{
		{name: "empty defaults to all", value: "", wantSound: true, wantBanner: true, wantMode: "all", wantOK: true},
		{name: "all", value: "all", wantSound: true, wantBanner: true, wantMode: "all", wantOK: true},
		{name: "banner", value: "banner", wantBanner: true, wantMode: "banner", wantOK: true},
		{name: "sound", value: "sound", wantSound: true, wantMode: "sound", wantOK: true},
		{name: "off", value: "off", wantMode: "off", wantOK: true},
		{name: "trim and fold case", value: " Banner\n", wantBanner: true, wantMode: "banner", wantOK: true},
		{name: "invalid falls back to all", value: "quiet", wantSound: true, wantBanner: true, wantMode: "all", wantOK: false},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, ok := parseNotificationConfig(c.value)
			if ok != c.wantOK {
				t.Fatalf("ok = %v, want %v", ok, c.wantOK)
			}
			if got.Sound != c.wantSound || got.Banner != c.wantBanner || got.Mode != c.wantMode {
				t.Fatalf("config = %+v, want sound=%v banner=%v mode=%q", got, c.wantSound, c.wantBanner, c.wantMode)
			}
		})
	}
}

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

func TestWatchTickNotificationConfigControlsDeliveryButMarksUnseen(t *testing.T) {
	cases := []struct {
		name       string
		cfg        notificationConfig
		wantSound  int
		wantBanner int
	}{
		{name: "all", cfg: notificationConfig{Sound: true, Banner: true, Mode: "all"}, wantSound: 1, wantBanner: 1},
		{name: "banner", cfg: notificationConfig{Banner: true, Mode: "banner"}, wantBanner: 1},
		{name: "sound", cfg: notificationConfig{Sound: true, Mode: "sound"}, wantSound: 1},
		{name: "off", cfg: notificationConfig{Mode: "off"}},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())

			fake := &fakeRunner{respond: func(args []string) (string, error) {
				joined := strings.Join(args, " ")
				switch {
				case joined == "list-sessions -F #{session_id}\t#{session_name}":
					return "$0\twork\n", nil
				case joined == "list-windows -a -F #{window_id}\t#{session_id}\t#{window_index}\t#{window_name}\t#{window_active}":
					return "@1\t$0\t0\teditor\t1\n", nil
				case joined == "list-panes -a -F #{pane_id}\t#{window_id}\t#{session_id}\t#{pane_index}\t#{pane_current_path}\t#{pane_current_command}\t#{pane_title}\t#{pane_pid}\t#{pane_active}":
					return "%1\t@1\t$0\t0\t/tmp\tclaude\tBuild setting\t100\t1\n", nil
				case joined == "capture-pane -p -e -J -t %1":
					return "Welcome back\n", nil
				case joined == "list-clients -F #{client_tty}":
					return "", nil
				default:
					return "", nil
				}
			}}
			prevRunner := tmuxRunner
			tmuxRunner = fake
			t.Cleanup(func() { tmuxRunner = prevRunner })

			prevLoadConfig := loadNotificationConfigFunc
			prevSound := notifySoundFunc
			prevBanner := notifyBannerFunc
			t.Cleanup(func() {
				loadNotificationConfigFunc = prevLoadConfig
				notifySoundFunc = prevSound
				notifyBannerFunc = prevBanner
			})

			loadNotificationConfigFunc = func() (notificationConfig, error) {
				return c.cfg, nil
			}
			soundCalls := 0
			bannerCalls := 0
			notifySoundFunc = func() (string, error) {
				soundCalls++
				return "test-sound", nil
			}
			notifyBannerFunc = func(title, subtitle, body, execute string) (string, error) {
				bannerCalls++
				return "test-banner", nil
			}

			agents := map[string]AgentState{
				"%1": {
					Kind:            AgentClaude,
					Status:          AgentStatusBusy,
					LastContent:     "Welcome back\n",
					StableSince:     time.Now().Add(-AgentIdleDebounce),
					KindConfirmedAt: time.Now(),
					PID:             "100",
				},
			}

			got, _ := watchTick(agents, map[string]probeRecord{}, 1)
			if soundCalls != c.wantSound || bannerCalls != c.wantBanner {
				t.Fatalf("delivery calls = sound:%d banner:%d, want sound:%d banner:%d", soundCalls, bannerCalls, c.wantSound, c.wantBanner)
			}
			if !got["%1"].Unseen {
				t.Fatalf("expected pane to still be marked unseen")
			}
		})
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
