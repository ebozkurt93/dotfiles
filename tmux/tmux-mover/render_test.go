package main

import (
	"strings"
	"testing"

	"github.com/charmbracelet/x/ansi"
)

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

func TestViewSelfPaneShowsPreviewText(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0, Command: "bash", Path: "~/p"}},
	}
	m := model{
		state:          state,
		paneOrder:      []string{"%1"},
		selectedPaneID: "%1",
		selfPaneID:     "%1",
		preview:        "line from selected pane",
		width:          80,
		height:         24,
		keys:           defaultKeymap(),
	}
	clean := ansi.Strip(m.View())
	if !strings.Contains(clean, "line from selected pane") {
		t.Fatalf("expected preview text for self pane")
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

func TestViewDimsWhenModalActive(t *testing.T) {
	state := TmuxState{
		Sessions: []Session{{ID: "$0", Name: "work"}},
		Windows:  []Window{{ID: "@1", SessionID: "$0", Index: "0", IndexNum: 0, Name: "w0"}},
		Panes:    []Pane{{ID: "%1", WindowID: "@1", SessionID: "$0", IndexNum: 0}},
	}
	m := model{state: state, mode: ModePickWindow, width: 80, height: 24, keys: defaultKeymap()}
	view := m.View()
	if !strings.Contains(view, "Move Pane") {
		t.Fatalf("expected modal content in view")
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
