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

	rows := buildTreeRows(state, "%1", 80, nil, nil, "", "", nil, 0)
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

func TestFilterStateSessionMatchIncludesSessionPanes(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}, {ID: "$1", Name: "ops"}},
		Windows: []Window{
			{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "editor"},
			{ID: "@2", SessionID: "$1", Index: "0", IndexNum: 0, Name: "shell"},
		},
		Panes: []Pane{
			{ID: "%1", WindowID: "@1", SessionID: "$0", Command: "nvim"},
			{ID: "%2", WindowID: "@2", SessionID: "$1", Command: "bash"},
		},
	}

	filtered := filterState(state, "work")
	if len(filtered.Sessions) != 1 || filtered.Sessions[0].ID != "$0" {
		t.Fatalf("expected only session $0, got %+v", filtered.Sessions)
	}
	if len(filtered.Windows) != 1 || filtered.Windows[0].ID != "@1" {
		t.Fatalf("expected only window @1, got %+v", filtered.Windows)
	}
	if len(filtered.Panes) != 1 || filtered.Panes[0].ID != "%1" {
		t.Fatalf("expected only pane %%1, got %+v", filtered.Panes)
	}
}

func TestFilterStateWindowMatchIncludesWindowPanes(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows: []Window{
			{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "editor"},
			{ID: "@2", SessionID: "$0", Index: "1", IndexNum: 1, Name: "logs"},
		},
		Panes: []Pane{
			{ID: "%1", WindowID: "@1", SessionID: "$0", Command: "nvim"},
			{ID: "%2", WindowID: "@2", SessionID: "$0", Command: "tail"},
		},
	}

	filtered := filterState(state, "editor")
	if len(filtered.Windows) != 1 || filtered.Windows[0].ID != "@1" {
		t.Fatalf("expected only window @1, got %+v", filtered.Windows)
	}
	if len(filtered.Panes) != 1 || filtered.Panes[0].ID != "%1" {
		t.Fatalf("expected pane %%1 to be included, got %+v", filtered.Panes)
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
	rows := buildTreeRows(state, "%1", 80, nil, nil, "", "", nil, 0)
	joined := strings.Join(rows.rows, "\n")
	if !strings.Contains(joined, "work") {
		t.Fatalf("expected session header")
	}
	if !strings.Contains(joined, "w0") {
		t.Fatalf("expected window header")
	}
}

func TestInitialWindowTargetIndexSelectsPrevious(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows: []Window{
			{ID: "@1", SessionID: "$0", IndexNum: 0, Name: "w0"},
			{ID: "@2", SessionID: "$0", IndexNum: 1, Name: "w1"},
			{ID: "@3", SessionID: "$0", IndexNum: 2, Name: "w2"},
		},
		Panes: []Pane{{ID: "%1", WindowID: "@2", SessionID: "$0", IndexNum: 0}},
	}
	// current window = @2; choices = [@1, @3]; previous of @2 in state.Windows is @1 -> choice index 0
	m := model{state: state, selectedPaneID: "%1", selectedPanes: map[string]bool{}}
	got := initialWindowTargetIndex(m)
	if got != 0 {
		t.Fatalf("expected choice index 0 (@1), got %d", got)
	}
}

func TestInitialWindowTargetIndexWraps(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows: []Window{
			{ID: "@1", SessionID: "$0", IndexNum: 0, Name: "w0"},
			{ID: "@2", SessionID: "$0", IndexNum: 1, Name: "w1"},
			{ID: "@3", SessionID: "$0", IndexNum: 2, Name: "w2"},
		},
		Panes: []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0}},
	}
	// current window = @1 (first); choices = [@2, @3]; previous wraps to @3 -> choice index 1
	m := model{state: state, selectedPaneID: "%1", selectedPanes: map[string]bool{}}
	got := initialWindowTargetIndex(m)
	if got != 1 {
		t.Fatalf("expected choice index 1 (@3), got %d", got)
	}
}

func TestInitialSessionTargetIndexSelectsPrevious(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{
			{ID: "$0", Name: "a"},
			{ID: "$1", Name: "b"},
			{ID: "$2", Name: "c"},
		},
		Windows: []Window{{ID: "@1", SessionID: "$1", IndexNum: 0, Name: "w0"}},
		Panes:   []Pane{{ID: "%1", WindowID: "@1", SessionID: "$1", IndexNum: 0}},
	}
	// current session = $1 (index 1); choices = [$0, $2]; previous is $0 -> choice index 0
	m := model{state: state, selectedPaneID: "%1", selectedPanes: map[string]bool{}}
	got := initialSessionTargetIndex(m)
	if got != 0 {
		t.Fatalf("expected choice index 0 ($0), got %d", got)
	}
}

func TestBuildTreeRowsGolden(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash", Path: "~/p"}},
	}
	rows := buildTreeRows(state, "%1", 120, nil, nil, "", "", nil, 0)
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

func buildManyAgentPanesState() (TmuxState, map[string]AgentState) {
	sessions := []Session{{ID: "$0", Name: "work"}}
	windows := []Window{}
	panes := []Pane{}
	agents := map[string]AgentState{}
	statuses := []AgentStatus{
		AgentStatusWaiting,
		AgentStatusBusy,
		AgentStatusIdle, AgentStatusIdle, AgentStatusIdle, AgentStatusIdle,
	}
	for i, status := range statuses {
		windowID := "@" + string(rune('0'+i))
		paneID := "%" + string(rune('0'+i))
		windows = append(windows, Window{ID: windowID, SessionID: "$0", Index: string(rune('0' + i)), IndexNum: i, Name: "w"})
		panes = append(panes, Pane{ID: paneID, WindowID: windowID, SessionID: "$0", IndexNum: 0, Command: "claude"})
		agents[paneID] = AgentState{Kind: AgentClaude, Status: status}
	}
	return TmuxState{Sessions: sessions, Windows: windows, Panes: panes}, agents
}

func TestEnsureVisibleScrollsAgentDashboardToKeepSelectionVisible(t *testing.T) {
	state, agents := buildManyAgentPanesState()

	base := model{
		width:  200,
		height: 20,
		state:  state,
		agents: agents,
		keys:   defaultKeymap(),
	}
	base.agentView = true

	dash := buildAgentDashboardRows(base, state, "", 200)
	if len(dash.rows) <= 10 {
		t.Fatalf("expected enough rows to force scrolling, got %d", len(dash.rows))
	}

	// Select the last (deepest) pane and confirm ensureVisible scrolls down
	// to reveal it instead of leaving the dashboard rendering top-anchored.
	m := base
	m.selectedPaneID = "%5"
	m.lastSelectedID = "%5"
	m = ensureVisible(m)

	listWidth, _, listHeight, _, _, _, _, _, _ := layoutDims(m, max(1, m.width-2))
	visibleRows := max(1, listHeight-2)
	dashAfter := buildAgentDashboardRows(m, state, "%5", max(10, listWidth-2))

	if dashAfter.selectedRow < m.scroll || dashAfter.selectedRow >= m.scroll+visibleRows {
		t.Fatalf("selected row %d not within visible window [%d, %d)", dashAfter.selectedRow, m.scroll, m.scroll+visibleRows)
	}

	maxScroll := max(0, len(dashAfter.rows)-visibleRows)
	if m.scroll > maxScroll {
		t.Fatalf("scroll %d exceeds max scroll %d", m.scroll, maxScroll)
	}
	if m.scroll == 0 {
		t.Fatalf("expected scroll to advance past 0 to reveal a deep selection")
	}
}

func TestAgentOnlyStateKeepsOnlyAgentPanesAndAncestors(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}, {ID: "$1", Name: "other"}},
		Windows: []Window{
			{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"},
			{ID: "@2", SessionID: "$0", Index: "1", IndexNum: 1, Name: "w1"},
			{ID: "@3", SessionID: "$1", Index: "0", IndexNum: 0, Name: "w0"},
		},
		Panes: []Pane{
			{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "claude"},
			{ID: "%2", WindowID: "@2", SessionID: "$0", IndexNum: 0, Command: "nvim"},
			{ID: "%3", WindowID: "@3", SessionID: "$1", IndexNum: 0, Command: "zsh"},
		},
	}
	agents := map[string]AgentState{"%1": {Kind: AgentClaude}}

	got := agentOnlyState(state, agents)

	if len(got.Panes) != 1 || got.Panes[0].ID != "%1" {
		t.Fatalf("expected only pane %%1, got %+v", got.Panes)
	}
	if len(got.Windows) != 1 || got.Windows[0].ID != "@1" {
		t.Fatalf("expected only window @1, got %+v", got.Windows)
	}
	if len(got.Sessions) != 1 || got.Sessions[0].ID != "$0" {
		t.Fatalf("expected only session $0, got %+v", got.Sessions)
	}
}

func TestAgentOnlyStateEmptyWhenNoAgents(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "zsh"}},
	}
	got := agentOnlyState(state, nil)
	if len(got.Panes) != 0 || len(got.Windows) != 0 || len(got.Sessions) != 0 {
		t.Fatalf("expected empty state, got %+v", got)
	}
}
