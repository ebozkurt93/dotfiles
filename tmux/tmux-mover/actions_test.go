package main

import "testing"

func TestBuildWindowChoicesExcludesCurrent(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows: []Window{
			{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"},
			{ID: "@2", SessionID: "$0", Index: "1", IndexNum: 1, Name: "w1"},
		},
	}
	choices := buildWindowChoices(state, "@1")
	if len(choices) != 1 || choices[0].ID != "@2" {
		t.Fatalf("expected only @2, got %+v", choices)
	}
}

func TestBuildSessionChoicesExcludesCurrent(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}, {ID: "$1", Name: "dev"}},
	}
	choices := buildSessionChoices(state, "$0")
	if len(choices) != 1 || choices[0].ID != "$1" {
		t.Fatalf("expected only $1, got %+v", choices)
	}
}

func TestMovePanesToWindowSkipsSameWindow(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", IndexNum: 0}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0"}},
	}
	m := model{state: state, selfPaneID: "%1"}
	prev := tmuxRunner
	fake := &fakeRunner{}
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	moved, skipped, newWin, newSess, err := movePanesToWindow(m, []string{"%1"}, "@1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if moved != 0 || skipped != 1 {
		t.Fatalf("expected moved 0 skipped 1, got %d %d", moved, skipped)
	}
	if newWin != "" || newSess != "" {
		t.Fatalf("expected no self update")
	}
}

func TestReorderPaneKeepsSelectionByID(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes: []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0},
			{ID: "%2", WindowID: "@1", SessionID: "$0", IndexNum: 1}},
	}
	prev := tmuxRunner
	fake := &fakeRunner{}
	tmuxRunner = fake
	t.Cleanup(func() { tmuxRunner = prev })

	m := model{state: state, mode: ModeList, selectedPaneID: "%2", keys: defaultKeymap()}
	updated, _ := reorderPane(m, -1)
	got := updated.(model)
	if got.selectedPaneID != "%2" {
		t.Fatalf("expected selection to stay on %%2, got %q", got.selectedPaneID)
	}
}
