package main

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
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
		Panes: []Pane{
			{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash", Path: "~/p"},
		},
	}

	rows := buildTreeRows(state, "%1", 80, nil, nil, "", "")
	if rows.selectedRow < 0 {
		t.Fatalf("expected selected row")
	}
}

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

func TestWrapLegendItemsKeepsItemsTogether(t *testing.T) {
	items := []string{"a A", "b B", "c C"}
	lines := wrapLegendItems(items, 6)
	if len(lines) < 2 {
		t.Fatalf("expected wrap into multiple lines, got %d", len(lines))
	}
	for _, line := range lines {
		if strings.Contains(line, "a") && !strings.Contains(line, "A") {
			t.Fatalf("item split across lines")
		}
	}
}

func TestKeyHintsStyledNotEmpty(t *testing.T) {
	lines := keyHintsStyled(defaultKeymap(), 80)
	if len(lines) == 0 {
		t.Fatalf("expected key hints")
	}
}

func TestSelectPaneIndexByID(t *testing.T) {
	order := []string{"%1", "%2", "%3"}
	idx := selectPaneIndex(order, "%2", 0)
	if idx != 1 {
		t.Fatalf("expected index 1, got %d", idx)
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
		Panes: []Pane{
			{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash"},
		},
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

func TestRenderModalForModePickWindow(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0}},
	}
	m := model{state: state, mode: ModePickWindow, keys: defaultKeymap()}
	modal, ok := renderModalForMode(m, 80)
	if !ok {
		t.Fatalf("expected modal")
	}
	clean := ansi.Strip(modal)
	if !strings.Contains(clean, "Move Pane -> Window") {
		t.Fatalf("expected modal title")
	}
}

func TestRenderKeyBarShowsStatusAndFilter(t *testing.T) {
	keys := defaultKeymap()
	bar := renderKeyBar(keys, 80, 3, "vim", true, "Moved 1 pane(s)")
	clean := ansi.Strip(bar)
	if !strings.Contains(clean, "Moved 1 pane(s)") {
		t.Fatalf("expected status line")
	}
	if !strings.Contains(clean, "/ vim") {
		t.Fatalf("expected filter line")
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

func TestRenderPreviewSelfShowsBadge(t *testing.T) {
	panel := renderPreviewSelf(40, 6)
	clean := ansi.Strip(panel)
	if !strings.Contains(clean, "tmux-mover active") {
		t.Fatalf("expected self preview badge")
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

func TestSelectPaneIndexFallback(t *testing.T) {
	order := []string{"%1", "%2"}
	idx := selectPaneIndex(order, "%9", 1)
	if idx != 1 {
		t.Fatalf("expected fallback index 1, got %d", idx)
	}
}

func TestNormalizeKeymapFallback(t *testing.T) {
	empty := Keymap{}
	got := normalizeKeymap(empty)
	if len(got.MoveDown) == 0 || len(got.MovePane) == 0 {
		t.Fatalf("expected default keymap")
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

func TestKeyHintsStyledSingleLineAtWideWidth(t *testing.T) {
	lines := keyHintsStyled(defaultKeymap(), 200)
	if len(lines) == 0 {
		t.Fatalf("expected key hints")
	}
	got := ansi.Strip(strings.Join(lines, " "))
	if !strings.Contains(got, "↑/↓/j/k move selection") {
		t.Fatalf("legend missing move selection: %s", got)
	}
	if !strings.Contains(got, "/ filter") {
		t.Fatalf("legend missing filter: %s", got)
	}
	if !strings.Contains(got, "alt+j/alt+k swap pane") {
		t.Fatalf("legend missing swap pane: %s", got)
	}
	if !strings.Contains(got, "alt+J/alt+K swap window") {
		t.Fatalf("legend missing swap window: %s", got)
	}
	if !strings.Contains(got, "space select pane") {
		t.Fatalf("legend missing select pane: %s", got)
	}
}

func TestKeyHintsStyledWrapsAtNarrowWidth(t *testing.T) {
	lines := keyHintsStyled(defaultKeymap(), 40)
	if len(lines) < 2 {
		t.Fatalf("expected wrapped legend, got %d lines", len(lines))
	}
	for _, line := range lines {
		if len(strings.TrimSpace(ansi.Strip(line))) == 0 {
			t.Fatalf("expected non-empty legend line")
		}
	}
}

func TestRenderActionsPanelSections(t *testing.T) {
	panel := renderActionsPanel(nil, ModeList, "", "idle", "", false, "", defaultKeymap(), 120, 20)
	clean := ansi.Strip(panel)
	if !strings.Contains(clean, "Status") {
		t.Fatalf("expected Status section")
	}
	if !strings.Contains(clean, "Keys") {
		t.Fatalf("expected Keys section")
	}
	if !strings.Contains(clean, "Recent") {
		t.Fatalf("expected Recent section")
	}
}

func TestWrapLegendItemsGolden(t *testing.T) {
	items := []string{
		"a one",
		"b two",
		"c three",
	}
	lines := wrapLegendItems(items, 12)
	if len(lines) < 2 {
		t.Fatalf("expected wrapped legend")
	}
	joined := ansi.Strip(strings.Join(lines, "\n"))
	if !strings.Contains(joined, "a one") || !strings.Contains(joined, "b two") || !strings.Contains(joined, "c three") {
		t.Fatalf("legend wrap mismatch:\n%s", joined)
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

func TestConsumeCount(t *testing.T) {
	buf := "12"
	if got := consumeCount(&buf, 1); got != 12 {
		t.Fatalf("expected 12, got %d", got)
	}
	if buf != "" {
		t.Fatalf("expected buffer cleared")
	}
}

func TestRenderChoiceListContainsTitleAndItems(t *testing.T) {
	choices := []choice{{ID: "@1", Label: "work 0:w0"}, {ID: "@2", Label: "work 1:w1"}}
	panel := renderChoiceList("Move Pane -> Window", choices, 0, 60, 10)
	clean := ansi.Strip(panel)
	if !strings.Contains(clean, "Move Pane -> Window") {
		t.Fatalf("expected title")
	}
	if !strings.Contains(clean, "work 0:w0") {
		t.Fatalf("expected choice label")
	}
}

func TestRenderChoiceListEmptyShowsNoTargets(t *testing.T) {
	panel := renderChoiceList("Move Pane -> Window", nil, 0, 40, 6)
	clean := ansi.Strip(panel)
	if !strings.Contains(clean, "(no targets)") {
		t.Fatalf("expected empty state")
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

func TestRenderMainPanelModes(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash", Path: "~/p"}},
	}
	m := model{state: state, paneOrder: []string{"%1"}, selectedPaneID: "%1", keys: defaultKeymap()}
	m.mode = ModePickWindow
	panel := renderMainPanel(m, 60, 10)
	if !strings.Contains(ansi.Strip(panel), "Panes") {
		t.Fatalf("expected list panel")
	}
	m.mode = ModePickSession
	panel = renderMainPanel(m, 60, 10)
	if !strings.Contains(ansi.Strip(panel), "Panes") {
		t.Fatalf("expected list panel")
	}
}
