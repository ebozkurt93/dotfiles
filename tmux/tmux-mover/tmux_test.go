package main

import (
	"errors"
	"reflect"
	"strings"
	"testing"
)

type fakeRunner struct {
	calls  [][]string
	err    error
	output string
}

func (r *fakeRunner) Run(args ...string) (string, error) {
	r.calls = append(r.calls, args)
	return r.output, r.err
}

func TestParseSessionsOutput(t *testing.T) {
	input := "$0\twork\n$1\tdev\n"
	got := parseSessionsOutput(input)
	want := []Session{{ID: "$0", Name: "work"}, {ID: "$1", Name: "dev"}}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseSessionsOutput mismatch: %+v", got)
	}
}

func TestParseSessionsOutputSkipsBadLines(t *testing.T) {
	input := "$0\twork\ninvalid\n"
	got := parseSessionsOutput(input)
	if len(got) != 1 {
		t.Fatalf("expected 1 session, got %d", len(got))
	}
}

func TestParseWindowsOutput(t *testing.T) {
	input := "@1\t$0\t0\teditor\n@2\t$0\t1\tlogs\n"
	got := parseWindowsOutput(input)
	if len(got) != 2 {
		t.Fatalf("expected 2 windows, got %d", len(got))
	}
	if got[0].IndexNum != 0 || got[1].IndexNum != 1 {
		t.Fatalf("expected index numbers 0,1 got %d,%d", got[0].IndexNum, got[1].IndexNum)
	}
}

func TestParsePanesOutput(t *testing.T) {
	input := "%1\t@1\t$0\t0\t~/proj\tnvim\tapi\n%2\t@1\t$0\t1\t~/proj\tbash\t\n"
	got := parsePanesOutput(input)
	if len(got) != 2 {
		t.Fatalf("expected 2 panes, got %d", len(got))
	}
	if got[0].IndexNum != 0 || got[1].IndexNum != 1 {
		t.Fatalf("expected pane indexes 0,1 got %d,%d", got[0].IndexNum, got[1].IndexNum)
	}
}

func TestApplyPaneMove(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	action := StagedAction{Type: ActionPaneMove, SourceID: "%1", TargetID: "@2"}
	if err := applyPaneMove(action); err != nil {
		t.Fatalf("applyPaneMove error: %v", err)
	}

	if len(fake.calls) != 1 {
		t.Fatalf("expected 1 call, got %d", len(fake.calls))
	}
	got := strings.Join(fake.calls[0], " ")
	want := "join-pane -d -s %1 -t @2"
	if got != want {
		t.Fatalf("expected %q got %q", want, got)
	}
}

func TestApplyWindowMove(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	action := StagedAction{Type: ActionWindowMove, SourceID: "@2", TargetID: "$1"}
	if err := applyWindowMove(action); err != nil {
		t.Fatalf("applyWindowMove error: %v", err)
	}
	got := strings.Join(fake.calls[0], " ")
	want := "move-window -d -s @2 -t $1"
	if got != want {
		t.Fatalf("expected %q got %q", want, got)
	}
}

func TestApplySessionCreateNamed(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	if err := applySessionCreate("new"); err != nil {
		t.Fatalf("applySessionCreate error: %v", err)
	}
	got := strings.Join(fake.calls[0], " ")
	want := "new-session -d -s new"
	if got != want {
		t.Fatalf("expected %q got %q", want, got)
	}
}

func TestApplySessionCreateUnnamed(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	if err := applySessionCreate(""); err != nil {
		t.Fatalf("applySessionCreate error: %v", err)
	}
	got := strings.Join(fake.calls[0], " ")
	want := "new-session -d"
	if got != want {
		t.Fatalf("expected %q got %q", want, got)
	}
}

func TestApplyPaneKill(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	if err := applyPaneKill("%9"); err != nil {
		t.Fatalf("applyPaneKill error: %v", err)
	}
	got := strings.Join(fake.calls[0], " ")
	want := "kill-pane -t %9"
	if got != want {
		t.Fatalf("expected %q got %q", want, got)
	}
}

func TestApplyPaneBreak(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	if err := applyPaneBreak("%9"); err != nil {
		t.Fatalf("applyPaneBreak error: %v", err)
	}
	got := strings.Join(fake.calls[0], " ")
	want := "break-pane -d -s %9"
	if got != want {
		t.Fatalf("expected %q got %q", want, got)
	}
}

func TestPaneLocation(t *testing.T) {
	fake := &fakeRunner{output: "@3\t$1"}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	windowID, sessionID, err := paneLocation("%9")
	if err != nil {
		t.Fatalf("paneLocation error: %v", err)
	}
	if windowID != "@3" || sessionID != "$1" {
		t.Fatalf("unexpected location: %s %s", windowID, sessionID)
	}
}

func TestApplyPaneMoveMissingArgs(t *testing.T) {
	if err := applyPaneMove(StagedAction{Type: ActionPaneMove}); err == nil {
		t.Fatalf("expected error")
	}
}

func TestApplyWindowMoveMissingArgs(t *testing.T) {
	if err := applyWindowMove(StagedAction{Type: ActionWindowMove}); err == nil {
		t.Fatalf("expected error")
	}
}

func TestRefocusSelfTargetsClient(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	if err := refocusSelf("%1", "$0", "@1", "c0"); err != nil {
		t.Fatalf("refocusSelf error: %v", err)
	}
	if len(fake.calls) < 3 {
		t.Fatalf("expected 3 tmux calls, got %d", len(fake.calls))
	}
	if strings.Join(fake.calls[0], " ") != "switch-client -c c0 -t $0" {
		t.Fatalf("unexpected switch-client call")
	}
	if strings.Join(fake.calls[1], " ") != "select-window -t @1" {
		t.Fatalf("unexpected select-window call")
	}
	if strings.Join(fake.calls[2], " ") != "select-pane -t %1" {
		t.Fatalf("unexpected select-pane call")
	}
}

func TestApplyPaneSwap(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	if err := applyPaneSwap("%1", "%2"); err != nil {
		t.Fatalf("applyPaneSwap error: %v", err)
	}
	got := strings.Join(fake.calls[0], " ")
	want := "swap-pane -d -s %1 -t %2"
	if got != want {
		t.Fatalf("expected %q got %q", want, got)
	}
}

func TestApplyWindowSwap(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	if err := applyWindowSwap("@1", "@2"); err != nil {
		t.Fatalf("applyWindowSwap error: %v", err)
	}
	got := strings.Join(fake.calls[0], " ")
	want := "swap-window -d -s @1 -t @2"
	if got != want {
		t.Fatalf("expected %q got %q", want, got)
	}
}

func TestTmuxOutputError(t *testing.T) {
	fake := &fakeRunner{err: errors.New("boom")}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	_, err := tmuxOutput("list-sessions")
	if err == nil {
		t.Fatalf("expected error")
	}
}
