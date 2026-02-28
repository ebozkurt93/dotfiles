package main

import tea "github.com/charmbracelet/bubbletea"

type model struct {
	width          int
	height         int
	state          TmuxState
	err            error
	selectedIndex  int
	scroll         int
	selectedPaneID string
	lastSelectedID string
	selfPaneID     string
	selfSessionID  string
	selfWindowID   string
	selfClientID   string
	selfIsPopup    bool
	paneOrder      []string
	preview        string
	previewErr     error
	staged         []StagedAction
	mode           Mode
	targetIndex    int
	input          string
	status         string
	keys           Keymap
	selectedPanes  map[string]bool
	filterInput    string
	filtering      bool
	filterActive   bool
	countBuffer    string
}

type Mode int

const (
	ModeList Mode = iota
	ModePickWindow
	ModePickSession
	ModeNewSession
	ModeConfirmDelete
)

type Keymap struct {
	Quit              []string
	Cancel            []string
	MoveDown          []string
	MoveUp            []string
	MovePane          []string
	MoveWindow        []string
	CreateSession     []string
	DeletePanes       []string
	BreakPane         []string
	ConfirmYes        []string
	ConfirmNo         []string
	ReorderPaneUp     []string
	ReorderPaneDown   []string
	ReorderWindowUp   []string
	ReorderWindowDown []string
	TogglePaneSelect  []string
	SelectNext        []string
	SelectPrev        []string
	ClearSelection    []string
	Accept            []string
	Backspace         []string
}

func defaultKeymap() Keymap {
	return Keymap{
		Quit:              []string{"q", "ctrl+c"},
		Cancel:            []string{"esc"},
		MoveDown:          []string{"j", "down"},
		MoveUp:            []string{"k", "up"},
		MovePane:          []string{"m"},
		MoveWindow:        []string{"M"},
		CreateSession:     []string{"s"},
		DeletePanes:       []string{"d"},
		BreakPane:         []string{"b"},
		ConfirmYes:        []string{"y"},
		ConfirmNo:         []string{"n"},
		ReorderPaneUp:     []string{"alt+k", "alt+up"},
		ReorderPaneDown:   []string{"alt+j", "alt+down"},
		ReorderWindowUp:   []string{"alt+K", "alt+shift+up"},
		ReorderWindowDown: []string{"alt+J", "alt+shift+down"},
		TogglePaneSelect:  []string{" "},
		SelectNext:        []string{"tab"},
		SelectPrev:        []string{"shift+tab"},
		ClearSelection:    []string{"c"},
		Accept:            []string{"enter"},
		Backspace:         []string{"backspace"},
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(loadStateCmd(), stateTickCmd(), loadSelfTargetCmd())
}
