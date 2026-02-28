package main

import (
	"strings"
	"testing"

	"github.com/charmbracelet/x/ansi"
)

func TestBuildPaneOrderSorted(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$1", Name: "b"}, {ID: "$0", Name: "a"}},
		Windows: []Window{
			{ID: "@2", SessionID: "$0", Index: "1", IndexNum: 1, Name: "w1"},
			{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"},
			{ID: "@3", SessionID: "$1", Index: "0", IndexNum: 0, Name: "wb"},
		},
		Panes: []Pane{
			{ID: "%2", WindowID: "@1", SessionID: "$0", IndexNum: 1},
			{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0},
			{ID: "%3", WindowID: "@2", SessionID: "$0", IndexNum: 0},
			{ID: "%4", WindowID: "@3", SessionID: "$1", IndexNum: 0},
		},
	}

	order := buildPaneOrder(state)
	got := strings.Join(order, ",")
	// sessions sorted by name: a then b; windows by index; panes by index
	want := "%1,%2,%3,%4"
	if got != want {
		t.Fatalf("expected order %q, got %q", want, got)
	}
}

func TestBuildTreeRowsSelectedRow(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash", Path: "~/p"}},
	}

	rows := buildTreeRows(state, "%1", 80, nil, nil, "", "")
	if rows.selectedRow < 0 {
		t.Fatalf("expected selected row")
	}
}

func TestCurrentPaneIDUsesFilteredOrder(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", IndexNum: 0, Name: "w0"}},
		Panes: []Pane{
			{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash"},
			{ID: "%2", WindowID: "@1", SessionID: "$0", IndexNum: 1, Command: "vim"},
		},
	}

	m := model{
		state:         state,
		filterActive:  true,
		filterInput:   "vim",
		selectedIndex: 0,
	}

	if got := currentPaneID(m); got != "%2" {
		t.Fatalf("expected %%2, got %q", got)
	}
}

func TestEffectiveSelectedPaneIDPrefersLast(t *testing.T) {
	order := []string{"%1", "%2"}
	got := effectiveSelectedPaneID(order, "%9", "%2", 0)
	if got != "%2" {
		t.Fatalf("expected %%2, got %q", got)
	}
}

func TestSyncSelectionUsesFilteredOrder(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", IndexNum: 0, Name: "w0"}},
		Panes: []Pane{
			{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash"},
			{ID: "%2", WindowID: "@1", SessionID: "$0", IndexNum: 1, Command: "vim"},
		},
	}

	m := model{
		state:          state,
		selectedPaneID: "%1",
		lastSelectedID: "%1",
		filterActive:   true,
		filterInput:    "vim",
	}

	m = syncSelection(m)
	if m.selectedPaneID != "%2" {
		t.Fatalf("expected %%2 selected, got %q", m.selectedPaneID)
	}
	if m.selectedIndex != 0 {
		t.Fatalf("expected selected index 0, got %d", m.selectedIndex)
	}
}

func TestSyncSelectionClearsWhenFilterEmpty(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash"}},
	}

	m := model{
		state:          state,
		selectedPaneID: "%1",
		lastSelectedID: "%1",
		filterActive:   true,
		filterInput:    "does-not-match",
	}

	m = syncSelection(m)
	if m.selectedPaneID != "" {
		t.Fatalf("expected empty selection, got %q", m.selectedPaneID)
	}
	if m.selectedIndex != 0 {
		t.Fatalf("expected selected index 0, got %d", m.selectedIndex)
	}
}

func TestFilterStateMatchesPaneFields(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "editor"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", Command: "nvim", Path: "/tmp/project", Title: "api"}},
	}
	filtered := filterState(state, "api")
	if len(filtered.Panes) != 1 {
		t.Fatalf("expected pane match")
	}
}

func TestFilterPopupState(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", IndexNum: 0}, {ID: "@2", SessionID: "$0", IndexNum: 1}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1"}, {ID: "%2", WindowID: "@2"}},
	}
	filtered := filterPopupState(state, "@2")
	if len(filtered.Windows) != 1 || filtered.Windows[0].ID != "@1" {
		t.Fatalf("expected popup window filtered")
	}
	if len(filtered.Panes) != 1 || filtered.Panes[0].ID != "%1" {
		t.Fatalf("expected popup panes filtered")
	}
}

func TestWindowIDForPane(t *testing.T) {
	state := TmuxState{Panes: []Pane{{ID: "%1", WindowID: "@1"}}}
	if got := windowIDForPane(state, "%1"); got != "@1" {
		t.Fatalf("expected @1, got %q", got)
	}
}

func TestSessionIDForWindow(t *testing.T) {
	state := TmuxState{Windows: []Window{{ID: "@1", SessionID: "$0"}}}
	if got := sessionIDForWindow(state, "@1"); got != "$0" {
		t.Fatalf("expected $0, got %q", got)
	}
}

func TestNeighborWindowIDLocal(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "a"}},
		Windows: []Window{
			{ID: "@1", SessionID: "$0", IndexNum: 0},
			{ID: "@2", SessionID: "$0", IndexNum: 1},
		},
	}
	if got := neighborWindowIDLocal(state, "@1", 1); got != "@2" {
		t.Fatalf("expected @2, got %q", got)
	}
}

func TestNeighborPaneIDLocal(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "a"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", IndexNum: 0}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0}, {ID: "%2", WindowID: "@1", SessionID: "$0", IndexNum: 1}},
	}
	if got := neighborPaneIDLocal(state, "%1", 1); got != "%2" {
		t.Fatalf("expected %%2, got %q", got)
	}
}

func TestBuildTreeRowsIncludesHeaders(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash", Path: "~/p"}},
	}
	rows := buildTreeRows(state, "%1", 80, nil, nil, "", "")
	joined := strings.Join(rows.rows, "\n")
	if !strings.Contains(joined, "work") {
		t.Fatalf("expected session header")
	}
	if !strings.Contains(joined, "w0") {
		t.Fatalf("expected window header")
	}
}

func TestBuildTreeRowsGolden(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash", Path: "~/p"}},
	}
	rows := buildTreeRows(state, "%1", 120, nil, nil, "", "")
	if len(rows.rows) < 3 {
		t.Fatalf("expected at least 3 rows, got %d", len(rows.rows))
	}
	strip := func(s string) string {
		return strings.TrimRight(ansi.Strip(s), " ")
	}
	joined := strings.Join([]string{strip(rows.rows[0]), strip(rows.rows[1]), strip(rows.rows[2])}, "\n")
	if !strings.Contains(joined, "work") {
		t.Fatalf("expected session row")
	}
	if !strings.Contains(joined, "0:w0") {
		t.Fatalf("expected window row")
	}
	if !strings.Contains(joined, "bash  ~/p") {
		t.Fatalf("expected pane row")
	}
}
