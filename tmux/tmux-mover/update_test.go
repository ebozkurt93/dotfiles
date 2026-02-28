package main

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func TestUpdateConfirmDeleteIgnoresMovementKeys(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", IndexNum: 0, Name: "w0"}},
		Panes: []Pane{
			{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0},
			{ID: "%2", WindowID: "@1", SessionID: "$0", IndexNum: 1},
		},
	}

	m := model{
		state:          state,
		mode:           ModeConfirmDelete,
		selectedIndex:  0,
		selectedPaneID: "%1",
		keys:           defaultKeymap(),
	}

	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'j'}})
	next := updated.(model)
	if next.selectedIndex != 0 {
		t.Fatalf("expected selected index unchanged, got %d", next.selectedIndex)
	}
	if next.mode != ModeConfirmDelete {
		t.Fatalf("expected mode confirm delete, got %v", next.mode)
	}
}

func TestUpdateConfirmDeleteYesDeletes(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", IndexNum: 0, Name: "w0"}},
		Panes: []Pane{
			{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0},
		},
	}

	m := model{
		state:          state,
		mode:           ModeConfirmDelete,
		selectedPaneID: "%1",
		paneOrder:      []string{"%1"},
		keys:           defaultKeymap(),
	}

	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'y'}})
	next := updated.(model)
	if next.mode != ModeList {
		t.Fatalf("expected mode list, got %v", next.mode)
	}
	if next.status != "Deleted 1 pane(s)" {
		t.Fatalf("unexpected status: %q", next.status)
	}
	if len(fake.calls) != 1 {
		t.Fatalf("expected 1 tmux call, got %d", len(fake.calls))
	}
	if strings.Join(fake.calls[0], " ") != "kill-pane -t %1" {
		t.Fatalf("unexpected tmux call: %s", strings.Join(fake.calls[0], " "))
	}
}

func TestUpdateNewSessionInputAndCreate(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	m := model{mode: ModeNewSession, keys: defaultKeymap()}

	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'a'}})
	updated, _ = updated.(model).Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'b'}})
	updated, _ = updated.(model).Update(tea.KeyMsg{Type: tea.KeyBackspace})
	updated, cmd := updated.(model).Update(tea.KeyMsg{Type: tea.KeyEnter})
	final := updated.(model)

	if final.input != "" {
		t.Fatalf("expected input cleared, got %q", final.input)
	}
	if final.mode != ModeList {
		t.Fatalf("expected mode list, got %v", final.mode)
	}
	if cmd == nil {
		t.Fatalf("expected command from create session")
	}
	if len(fake.calls) != 1 {
		t.Fatalf("expected 1 tmux call, got %d", len(fake.calls))
	}
	if strings.Join(fake.calls[0], " ") != "new-session -d -s a" {
		t.Fatalf("unexpected tmux call: %s", strings.Join(fake.calls[0], " "))
	}
}

func TestUpdateEnterJumpsToPane(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0}},
	}

	m := model{
		state:          state,
		mode:           ModeList,
		selectedPaneID: "%1",
		selfClientID:   "c0",
		keys:           defaultKeymap(),
	}

	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	if cmd == nil {
		t.Fatalf("expected quit command")
	}
	if _, ok := cmd().(tea.QuitMsg); !ok {
		t.Fatalf("expected quit message")
	}
	_ = updated
	if len(fake.calls) != 3 {
		t.Fatalf("expected 3 tmux calls, got %d", len(fake.calls))
	}
	if strings.Join(fake.calls[0], " ") != "switch-client -c c0 -t $0" {
		t.Fatalf("unexpected call 1: %s", strings.Join(fake.calls[0], " "))
	}
	if strings.Join(fake.calls[1], " ") != "select-window -t @1" {
		t.Fatalf("unexpected call 2: %s", strings.Join(fake.calls[1], " "))
	}
	if strings.Join(fake.calls[2], " ") != "select-pane -t %1" {
		t.Fatalf("unexpected call 3: %s", strings.Join(fake.calls[2], " "))
	}
}

func TestUpdateBreakPaneRefocusesSelf(t *testing.T) {
	fake := &fakeRunner{}
	prev := tmuxRunner
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0}},
	}

	m := model{
		state:          state,
		mode:           ModeList,
		selectedPaneID: "%1",
		selfPaneID:     "%1",
		selfSessionID:  "$0",
		selfWindowID:   "@1",
		selfClientID:   "c0",
		keys:           defaultKeymap(),
	}

	_, _ = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'b'}})
	if len(fake.calls) != 5 {
		t.Fatalf("expected 5 tmux calls, got %d", len(fake.calls))
	}
	if strings.Join(fake.calls[0], " ") != "break-pane -d -s %1" {
		t.Fatalf("unexpected call 1: %s", strings.Join(fake.calls[0], " "))
	}
	if strings.Join(fake.calls[1], " ") != "display-message -p -t %1 #{window_id}\t#{session_id}" {
		t.Fatalf("unexpected call 2: %s", strings.Join(fake.calls[1], " "))
	}
	if strings.Join(fake.calls[2], " ") != "switch-client -c c0 -t $0" {
		t.Fatalf("unexpected call 3: %s", strings.Join(fake.calls[2], " "))
	}
	if strings.Join(fake.calls[3], " ") != "select-window -t @1" {
		t.Fatalf("unexpected call 4: %s", strings.Join(fake.calls[3], " "))
	}
	if strings.Join(fake.calls[4], " ") != "select-pane -t %1" {
		t.Fatalf("unexpected call 5: %s", strings.Join(fake.calls[4], " "))
	}
}

func TestSelfTargetSetsSelection(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0}},
	}
	m := model{state: state, keys: defaultKeymap()}
	updated, _ := m.Update(selfTargetMsg{paneID: "%1", sessionID: "$0", windowID: "@1", clientID: "c0"})
	got := updated.(model)
	if got.selectedPaneID != "%1" {
		t.Fatalf("expected selected pane %%1, got %q", got.selectedPaneID)
	}
}
