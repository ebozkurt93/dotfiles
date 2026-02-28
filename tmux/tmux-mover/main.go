package main

import (
	"fmt"
	"os"
	"sort"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
	"github.com/mattn/go-runewidth"
)

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

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case stateMsg:
		m.state = msg.state
		m.err = msg.err
		m = ensureSelectionMaps(m)
		if m.selfIsPopup && m.selfWindowID != "" {
			m.state = filterPopupState(m.state, m.selfWindowID)
		}
		m.selectedPanes = pruneSelectedPanes(m.selectedPanes, m.state.Panes)
		// window selection derived from selected panes
		m.paneOrder = buildPaneOrder(m.state)
		if m.selfPaneID != "" {
			m.selfWindowID = windowIDForPane(m.state, m.selfPaneID)
		}
		if m.selectedPaneID == "" && m.selfPaneID != "" {
			m.selectedPaneID = m.selfPaneID
			m.lastSelectedID = m.selfPaneID
		}
		m = syncSelection(m)
		m = ensureVisible(m)
		if m.selectedPaneID != "" {
			return m, tea.Batch(loadPreviewCmd(m.selectedPaneID), stateTickCmd())
		}
		return m, stateTickCmd()
	case tea.KeyMsg:
		if m.filtering {
			if msg.Type == tea.KeyRunes {
				key := msg.String()
				m.filterInput += key
				m.filterActive = true
				m = syncSelection(m)
				m = ensureVisible(m)
				if m.selectedPaneID != "" {
					return m, loadPreviewCmd(m.selectedPaneID)
				}
				return m, nil
			}
			if msg.Type == tea.KeyEnter {
				m.filtering = false
				m.filterActive = true
				m = syncSelection(m)
				m = ensureVisible(m)
				if m.selectedPaneID != "" {
					return m, loadPreviewCmd(m.selectedPaneID)
				}
				return m, nil
			}
		}
		if m.mode == ModeNewSession {
			switch {
			case keyMatches(msg, m.keys.Cancel):
				m.mode = ModeList
				m.input = ""
				return m, nil
			case keyMatches(msg, m.keys.Accept):
				return acceptAction(m)
			case keyMatches(msg, m.keys.Backspace):
				if len(m.input) > 0 {
					m.input = m.input[:len(m.input)-1]
				}
				return m, nil
			default:
				if msg.Type == tea.KeyRunes {
					m.input += msg.String()
					return m, nil
				}
			}
		}
		if m.mode == ModeConfirmDelete {
			switch {
			case keyMatches(msg, m.keys.ConfirmYes):
				return confirmDeletePanes(m)
			case keyMatches(msg, m.keys.ConfirmNo):
				m.mode = ModeList
				m.status = "Delete cancelled"
				return m, nil
			case keyMatches(msg, m.keys.Cancel):
				m.mode = ModeList
				m.status = "Delete cancelled"
				return m, nil
			}
			return m, nil
		}
		switch {
		case keyMatches(msg, m.keys.Cancel):
			if m.mode != ModeList {
				m.mode = ModeList
				m.input = ""
				return m, nil
			}
			m.filtering = false
			m.filterInput = ""
			m.filterActive = false
			m.countBuffer = ""
			m = syncSelection(m)
			m = ensureVisible(m)
			if m.selectedPaneID != "" {
				return m, loadPreviewCmd(m.selectedPaneID)
			}
			return m, nil
		case keyMatches(msg, m.keys.Quit):
			return m, tea.Quit
		case keyMatches(msg, m.keys.MoveDown):
			return moveDownByCount(m, 1)
		case keyMatches(msg, m.keys.MoveUp):
			return moveUpByCount(m, 1)
		case keyMatches(msg, m.keys.ReorderPaneUp):
			return reorderPane(m, -1)
		case keyMatches(msg, m.keys.ReorderPaneDown):
			return reorderPane(m, 1)
		case keyMatches(msg, m.keys.ReorderWindowUp):
			return reorderWindow(m, -1)
		case keyMatches(msg, m.keys.ReorderWindowDown):
			return reorderWindow(m, 1)
		case keyMatches(msg, m.keys.TogglePaneSelect):
			if m.mode == ModeList {
				return togglePaneSelection(m)
			}
		case keyMatches(msg, m.keys.SelectNext):
			if m.mode == ModeList {
				updated, _ := togglePaneSelection(m)
				return moveDownByCount(updated.(model), 1)
			}
		case keyMatches(msg, m.keys.SelectPrev):
			if m.mode == ModeList {
				updated, _ := togglePaneSelection(m)
				return moveUpByCount(updated.(model), 1)
			}
		case keyMatches(msg, m.keys.ClearSelection):
			m.selectedPanes = map[string]bool{}
			m.status = "Cleared selections"
			return m, nil
		case keyMatches(msg, m.keys.MovePane):
			if m.mode == ModeList {
				m.mode = ModePickWindow
				m.targetIndex = 0
				return m, nil
			}
		case keyMatches(msg, m.keys.MoveWindow):
			if m.mode == ModeList {
				m.mode = ModePickSession
				m.targetIndex = 0
				return m, nil
			}
		case keyMatches(msg, m.keys.CreateSession):
			if m.mode == ModeList {
				m.mode = ModeNewSession
				m.input = ""
				return m, nil
			}
		case keyMatches(msg, m.keys.DeletePanes):
			if m.mode == ModeList {
				count := deletePaneCount(m)
				if count == 0 {
					m.status = "No pane selected"
					return m, nil
				}
				m.mode = ModeConfirmDelete
				m.status = fmt.Sprintf("Delete %d pane(s)? y/n", count)
				return m, nil
			}
		case keyMatches(msg, m.keys.BreakPane):
			if m.mode == ModeList {
				if m.selectedPaneID == "" {
					m.status = "No pane selected"
					return m, nil
				}
				if err := applyPaneBreak(m.selectedPaneID); err != nil {
					m.status = fmt.Sprintf("Error: %s", err)
					return m, nil
				}
				m.status = fmt.Sprintf("Broke out pane %s", m.selectedPaneID)
				if m.selectedPaneID == m.selfPaneID {
					if windowID, sessionID, err := paneLocation(m.selfPaneID); err == nil {
						m.selfWindowID = windowID
						m.selfSessionID = sessionID
					}
				}
				_ = refocusSelf(m.selfPaneID, m.selfSessionID, m.selfWindowID, m.selfClientID)
				return m, loadStateCmd()
			}
		case keyMatches(msg, m.keys.Accept):
			return acceptAction(m)
		case keyMatches(msg, m.keys.Backspace):
			if m.mode == ModeNewSession {
				if len(m.input) > 0 {
					m.input = m.input[:len(m.input)-1]
				}
				return m, nil
			}
			if m.filtering {
				if len(m.filterInput) > 0 {
					m.filterInput = m.filterInput[:len(m.filterInput)-1]
				}
				m = syncSelection(m)
				m = ensureVisible(m)
				if m.selectedPaneID != "" {
					return m, loadPreviewCmd(m.selectedPaneID)
				}
				return m, nil
			}
		default:
			if msg.Type == tea.KeyRunes {
				key := msg.String()
				if m.mode == ModeNewSession {
					m.input += key
					return m, nil
				}
				if key == "/" && m.mode == ModeList {
					m.filtering = true
					m.filterInput = ""
					m.filterActive = true
					m = syncSelection(m)
					return m, nil
				}
				if key >= "0" && key <= "9" {
					m.countBuffer += key
					return m, nil
				}
			}
		}
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m = ensureVisible(m)
	case previewMsg:
		if msg.paneID == currentPaneID(m) {
			m.preview = msg.text
			m.previewErr = msg.err
		}
		return m, nil
	case stateTickMsg:
		return m, loadStateCmd()
	case selfTargetMsg:
		if msg.err != nil {
			m.status = fmt.Sprintf("Error: %s", msg.err)
			return m, nil
		}
		prevSelf := m.selfPaneID
		m.selfPaneID = msg.paneID
		m.selfSessionID = msg.sessionID
		m.selfWindowID = msg.windowID
		m.selfClientID = msg.clientID
		m.selfIsPopup = msg.isPopup
		if msg.paneID != "" && prevSelf == "" {
			m.selectedPaneID = msg.paneID
			m.lastSelectedID = msg.paneID
		}
		m = syncSelection(m)
		m = ensureVisible(m)
		if m.selectedPaneID != "" {
			return m, loadPreviewCmd(m.selectedPaneID)
		}
	}

	return m, nil
}

func (m model) View() string {
	if m.err != nil {
		return fmt.Sprintf("Error: %s\n", m.err)
	}

	if len(m.state.Panes) == 0 {
		return "No panes found.\n"
	}

	availableWidth := max(1, m.width-2)
	listWidth, previewWidth, listHeight, previewHeight, keyBarHeight, vertical, gapWidth, gapVertical, gapTopBottom := layoutDims(m, availableWidth)
	list := renderMainPanel(m, listWidth, listHeight)
	previewText := m.preview
	previewErr := m.previewErr
	preview := ""
	if effectiveSelectedPaneID(activeOrder(m), m.selectedPaneID, m.lastSelectedID, m.selectedIndex) == m.selfPaneID {
		preview = renderPreviewSelf(previewWidth, previewHeight)
	} else {
		preview = renderPreview(previewText, previewErr, previewWidth, previewHeight)
	}
	keyBar := renderKeyBar(m.keys, availableWidth, keyBarHeight, m.filterInput, m.filtering, m.status)
	var body string
	if vertical {
		gapLine := strings.Repeat("\n", gapVertical)
		body = lipgloss.JoinVertical(lipgloss.Left, list, gapLine, preview)
	} else {
		gap := strings.Repeat(" ", gapWidth)
		top := lipgloss.JoinHorizontal(lipgloss.Top, list, gap, preview)
		body = top
	}
	if gapTopBottom > 0 {
		body = lipgloss.JoinVertical(lipgloss.Left, body, strings.Repeat("\n", gapTopBottom), keyBar)
	} else {
		body = lipgloss.JoinVertical(lipgloss.Left, body, keyBar)
	}
	if modal, ok := renderModalForMode(m, availableWidth); ok {
		contentHeight := max(12, m.height-4)
		body = dimBody(body)
		body = overlayModal(body, modal, availableWidth, contentHeight)
	}
	return fmt.Sprintf("%s\n", body)
}

func main() {
	p := tea.NewProgram(model{keys: defaultKeymap()}, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

type stateMsg struct {
	state TmuxState
	err   error
}

type previewMsg struct {
	paneID string
	text   string
	err    error
}

type stateTickMsg struct{}

type selfTargetMsg struct {
	paneID    string
	sessionID string
	windowID  string
	clientID  string
	isPopup   bool
	err       error
}

func loadStateCmd() tea.Cmd {
	return func() tea.Msg {
		state, err := loadTmuxState()
		return stateMsg{state: state, err: err}
	}
}

func loadPreviewCmd(paneID string) tea.Cmd {
	return func() tea.Msg {
		text, err := capturePane(paneID)
		return previewMsg{paneID: paneID, text: text, err: err}
	}
}

func stateTickCmd() tea.Cmd {
	return tea.Tick(1*time.Second, func(time.Time) tea.Msg {
		return stateTickMsg{}
	})
}

func loadSelfTargetCmd() tea.Cmd {
	return func() tea.Msg {
		paneID, err := currentTmuxPaneID()
		if err != nil {
			return selfTargetMsg{err: err}
		}
		sessionID, err := currentTmuxSessionID()
		if err != nil {
			return selfTargetMsg{err: err}
		}
		windowID, err := currentTmuxWindowID()
		if err != nil {
			return selfTargetMsg{err: err}
		}
		clientID, err := currentTmuxClientID()
		if err != nil {
			return selfTargetMsg{err: err}
		}
		isPopup, err := currentTmuxWindowPopup()
		if err != nil {
			return selfTargetMsg{err: err}
		}
		return selfTargetMsg{paneID: paneID, sessionID: sessionID, windowID: windowID, clientID: clientID, isPopup: isPopup}
	}
}

func renderMainPanel(m model, width int, height int) string {
	switch m.mode {
	default:
		filtered := activeState(m)
		order := buildPaneOrder(filtered)
		effectiveID := effectiveSelectedPaneID(order, m.selectedPaneID, m.lastSelectedID, m.selectedIndex)
		return renderPaneList(filtered, effectiveID, m.scroll, width, height, m.selectedPanes, nil, m.selfSessionID, m.selfWindowID)
	}
}

func moveDown(m model) (tea.Model, tea.Cmd) {
	switch m.mode {
	case ModePickWindow:
		choices := windowChoicesForMove(m)
		if len(choices) > 0 {
			m.targetIndex = min(m.targetIndex+1, len(choices)-1)
		}
		return m, nil
	case ModePickSession:
		choices := sessionChoicesForMove(m)
		if len(choices) > 0 {
			m.targetIndex = min(m.targetIndex+1, len(choices)-1)
		}
		return m, nil
	default:
		order := activeOrder(m)
		if len(order) > 0 {
			m = normalizeSelectedIndex(m)
			m.selectedIndex = min(m.selectedIndex+1, len(order)-1)
			m.selectedPaneID = currentPaneID(m)
			m.lastSelectedID = m.selectedPaneID
			m.status = ""
			m = ensureVisible(m)
			return m, loadPreviewCmd(m.selectedPaneID)
		}
		return m, nil
	}
}

func moveDownByCount(m model, defaultCount int) (tea.Model, tea.Cmd) {
	count := consumeCount(&m.countBuffer, defaultCount)
	var lastCmd tea.Cmd
	for i := 0; i < count; i++ {
		updated, cmd := moveDown(m)
		m = updated.(model)
		if cmd != nil {
			lastCmd = cmd
		}
	}
	return m, lastCmd
}

func moveUp(m model) (tea.Model, tea.Cmd) {
	switch m.mode {
	case ModePickWindow:
		if len(windowChoicesForMove(m)) > 0 {
			m.targetIndex = max(m.targetIndex-1, 0)
		}
		return m, nil
	case ModePickSession:
		if len(sessionChoicesForMove(m)) > 0 {
			m.targetIndex = max(m.targetIndex-1, 0)
		}
		return m, nil
	default:
		order := activeOrder(m)
		if len(order) > 0 {
			m = normalizeSelectedIndex(m)
			m.selectedIndex = max(m.selectedIndex-1, 0)
			m.selectedPaneID = currentPaneID(m)
			m.lastSelectedID = m.selectedPaneID
			m.status = ""
			m = ensureVisible(m)
			return m, loadPreviewCmd(m.selectedPaneID)
		}
		return m, nil
	}
}

func moveUpByCount(m model, defaultCount int) (tea.Model, tea.Cmd) {
	count := consumeCount(&m.countBuffer, defaultCount)
	var lastCmd tea.Cmd
	for i := 0; i < count; i++ {
		updated, cmd := moveUp(m)
		m = updated.(model)
		if cmd != nil {
			lastCmd = cmd
		}
	}
	return m, lastCmd
}

func acceptAction(m model) (tea.Model, tea.Cmd) {
	switch m.mode {
	case ModeList:
		if m.selectedPaneID == "" {
			return m, nil
		}
		if err := refocusPane(m, m.selectedPaneID); err != nil {
			m.status = fmt.Sprintf("Error: %s", err)
			return m, nil
		}
		return m, tea.Quit
	case ModePickWindow:
		choices := windowChoicesForMove(m)
		if len(choices) == 0 || m.selectedPaneID == "" {
			m.mode = ModeList
			return m, nil
		}
		if m.targetIndex >= len(choices) {
			m.targetIndex = 0
		}
		selected := selectedPaneIDs(m)
		if len(selected) == 0 {
			selected = []string{m.selectedPaneID}
		}
		moved, skipped, newWindowID, newSessionID, err := movePanesToWindow(m, selected, choices[m.targetIndex].ID)
		if err != nil {
			m.status = fmt.Sprintf("Error: %s", err)
		} else {
			m.status = fmt.Sprintf("Moved %d pane(s), skipped %d", moved, skipped)
			m.staged = append(m.staged, StagedAction{Type: ActionPaneMove, SourceID: selected[0], TargetID: choices[m.targetIndex].ID})
			m.selectedPanes = map[string]bool{}
			if newWindowID != "" {
				m.selfWindowID = newWindowID
			}
			if newSessionID != "" {
				m.selfSessionID = newSessionID
			}
			_ = refocusSelf(m.selfPaneID, m.selfSessionID, m.selfWindowID, m.selfClientID)
		}
		m.mode = ModeList
		return m, tea.Batch(loadStateCmd(), loadPreviewCmd(m.selectedPaneID))
	case ModePickSession:
		windowID := windowIDForPane(m.state, m.selectedPaneID)
		choices := sessionChoicesForMove(m)
		if len(choices) == 0 || windowID == "" {
			m.mode = ModeList
			return m, nil
		}
		if m.targetIndex >= len(choices) {
			m.targetIndex = 0
		}
		selected := selectedWindowIDsFromPanes(m)
		if len(selected) == 0 {
			selected = []string{windowID}
		}
		moved, skipped, newSessionID, err := moveWindowsToSession(m, selected, choices[m.targetIndex].ID)
		if err != nil {
			m.status = fmt.Sprintf("Error: %s", err)
		} else {
			m.status = fmt.Sprintf("Moved %d window(s), skipped %d", moved, skipped)
			m.staged = append(m.staged, StagedAction{Type: ActionWindowMove, SourceID: selected[0], TargetID: choices[m.targetIndex].ID})
			m.selectedPanes = map[string]bool{}
			if windowID != "" {
				_ = refocusSelf(m.selfPaneID, m.selfSessionID, windowID, m.selfClientID)
			}
			if newSessionID != "" {
				m.selfSessionID = newSessionID
			}
			_ = refocusSelf(m.selfPaneID, m.selfSessionID, m.selfWindowID, m.selfClientID)
		}
		m.mode = ModeList
		return m, tea.Batch(loadStateCmd(), loadPreviewCmd(m.selectedPaneID))
	case ModeNewSession:
		name := strings.TrimSpace(m.input)
		if err := applySessionCreate(name); err != nil {
			m.status = fmt.Sprintf("Error: %s", err)
		} else if name == "" {
			m.status = "Created new session"
		} else {
			m.status = fmt.Sprintf("Created session %s", name)
		}
		m.mode = ModeList
		m.input = ""
		return m, loadStateCmd()
	default:
		return m, nil
	}
}

func reorderPane(m model, direction int) (tea.Model, tea.Cmd) {
	if m.mode != ModeList {
		return m, nil
	}
	if m.selectedPaneID == "" {
		return m, nil
	}
	neighbor := neighborPaneIDLocal(m.state, m.selectedPaneID, direction)
	if neighbor == "" {
		m.status = "No pane to swap"
		return m, nil
	}
	if err := applyPaneSwap(m.selectedPaneID, neighbor); err != nil {
		m.status = fmt.Sprintf("Error: %s", err)
	} else {
		m.status = "Swapped pane"
		_ = refocusSelf(m.selfPaneID, m.selfSessionID, m.selfWindowID, m.selfClientID)
		m = syncSelection(m)
		m = ensureVisible(m)
		return m, loadPreviewCmd(m.selectedPaneID)
	}
	return m, tea.Batch(loadStateCmd(), loadPreviewCmd(m.selectedPaneID))
}

func reorderWindow(m model, direction int) (tea.Model, tea.Cmd) {
	if m.mode != ModeList {
		return m, nil
	}
	windowID := windowIDForPane(m.state, m.selectedPaneID)
	if windowID == "" {
		return m, nil
	}
	neighbor := neighborWindowIDLocal(m.state, windowID, direction)
	if neighbor == "" {
		m.status = "No window to swap"
		return m, nil
	}
	if err := applyWindowSwap(windowID, neighbor); err != nil {
		m.status = fmt.Sprintf("Error: %s", err)
	} else {
		m.status = "Swapped window"
		_ = refocusSelf(m.selfPaneID, m.selfSessionID, m.selfWindowID, m.selfClientID)
		m = syncSelection(m)
		m = ensureVisible(m)
		return m, loadPreviewCmd(m.selectedPaneID)
	}
	return m, tea.Batch(loadStateCmd(), loadPreviewCmd(m.selectedPaneID))
}

type choice struct {
	ID    string
	Label string
}

func buildWindowChoices(state TmuxState, excludeWindowID string) []choice {
	sessionByID := make(map[string]Session, len(state.Sessions))
	for _, s := range state.Sessions {
		sessionByID[s.ID] = s
	}
	choices := make([]choice, 0, len(state.Windows))
	for _, w := range state.Windows {
		if w.ID == excludeWindowID {
			continue
		}
		session := sessionByID[w.SessionID]
		label := fmt.Sprintf("%s %s:%s", session.Name, w.Index, w.Name)
		choices = append(choices, choice{ID: w.ID, Label: label})
	}
	return choices
}

func buildSessionChoices(state TmuxState, excludeSessionID string) []choice {
	choices := make([]choice, 0, len(state.Sessions))
	for _, s := range state.Sessions {
		if s.ID == excludeSessionID {
			continue
		}
		choices = append(choices, choice{ID: s.ID, Label: s.Name})
	}
	return choices
}

func windowChoicesForMove(m model) []choice {
	exclude := windowIDForPane(m.state, m.selectedPaneID)
	if len(selectedPaneIDs(m)) > 1 {
		exclude = ""
	}
	return buildWindowChoices(m.state, exclude)
}

func sessionChoicesForMove(m model) []choice {
	windowID := windowIDForPane(m.state, m.selectedPaneID)
	exclude := sessionIDForWindow(m.state, windowID)
	if len(selectedWindowIDsFromPanes(m)) > 1 {
		exclude = ""
	}
	return buildSessionChoices(m.state, exclude)
}

func windowIDForPane(state TmuxState, paneID string) string {
	for _, pane := range state.Panes {
		if pane.ID == paneID {
			return pane.WindowID
		}
	}
	return ""
}

func sessionIDForPane(state TmuxState, paneID string) string {
	for _, pane := range state.Panes {
		if pane.ID == paneID {
			return pane.SessionID
		}
	}
	return ""
}

func sessionIDForWindow(state TmuxState, windowID string) string {
	for _, window := range state.Windows {
		if window.ID == windowID {
			return window.SessionID
		}
	}
	return ""
}

func orderedWindows(state TmuxState) []Window {
	windowsBySession := make(map[string][]Window)
	for _, window := range state.Windows {
		windowsBySession[window.SessionID] = append(windowsBySession[window.SessionID], window)
	}
	for sessionID, windows := range windowsBySession {
		sort.SliceStable(windows, func(i, j int) bool {
			return windows[i].IndexNum < windows[j].IndexNum
		})
		windowsBySession[sessionID] = windows
	}
	sessions := orderedSessions(state)
	ordered := []Window{}
	for _, session := range sessions {
		ordered = append(ordered, windowsBySession[session.ID]...)
	}
	return ordered
}

func orderedSessions(state TmuxState) []Session {
	sessions := append([]Session(nil), state.Sessions...)
	sort.SliceStable(sessions, func(i, j int) bool {
		return sessions[i].Name < sessions[j].Name
	})
	return sessions
}

func filterPopupState(state TmuxState, popupWindowID string) TmuxState {
	if popupWindowID == "" {
		return state
	}
	panes := []Pane{}
	for _, pane := range state.Panes {
		if pane.WindowID != popupWindowID {
			panes = append(panes, pane)
		}
	}
	windows := []Window{}
	for _, window := range state.Windows {
		if window.ID != popupWindowID {
			windows = append(windows, window)
		}
	}
	return TmuxState{Sessions: state.Sessions, Windows: windows, Panes: panes}
}

func neighborPaneIDLocal(state TmuxState, paneID string, direction int) string {
	windowID := windowIDForPane(state, paneID)
	if windowID == "" {
		return ""
	}
	panes := []Pane{}
	for _, pane := range state.Panes {
		if pane.WindowID == windowID {
			panes = append(panes, pane)
		}
	}
	if len(panes) == 0 {
		return ""
	}
	sort.SliceStable(panes, func(i, j int) bool {
		return panes[i].IndexNum < panes[j].IndexNum
	})
	for i, pane := range panes {
		if pane.ID == paneID {
			idx := i + direction
			if idx >= 0 && idx < len(panes) {
				return panes[idx].ID
			}
			return ""
		}
	}
	return ""
}

func neighborWindowIDLocal(state TmuxState, windowID string, direction int) string {
	sessionID := sessionIDForWindow(state, windowID)
	if sessionID == "" {
		return ""
	}
	windows := []Window{}
	for _, window := range state.Windows {
		if window.SessionID == sessionID {
			windows = append(windows, window)
		}
	}
	if len(windows) == 0 {
		return ""
	}
	sort.SliceStable(windows, func(i, j int) bool {
		return windows[i].IndexNum < windows[j].IndexNum
	})
	for i, window := range windows {
		if window.ID == windowID {
			idx := i + direction
			if idx >= 0 && idx < len(windows) {
				return windows[idx].ID
			}
			return ""
		}
	}
	return ""
}

func renderChoiceList(title string, choices []choice, selected int, width int, height int) string {
	rowWidth := max(10, width-4)
	normalStyle := lipgloss.NewStyle().Width(rowWidth)
	selectedStyle := lipgloss.NewStyle().Width(rowWidth).Bold(true).Foreground(lipgloss.Color("2"))
	headerStyle := lipgloss.NewStyle().Bold(true).Width(rowWidth)
	rows := make([]string, 0, len(choices))
	for idx, choice := range choices {
		prefix := "  "
		if idx == selected {
			prefix = "› "
		}
		row := truncateRow(prefix+choice.Label, rowWidth)
		if idx == selected {
			rows = append(rows, selectedStyle.Render(row))
		} else {
			rows = append(rows, normalStyle.Render(row))
		}
	}
	if len(rows) == 0 {
		rows = append(rows, "(no targets)")
	}
	visible := sliceRows(rows, 0, max(1, height-2))
	content := lipgloss.JoinVertical(lipgloss.Left, visible...)
	separator := mutedSeparator(rowWidth)
	return modalFrame(title, content, width, height, headerStyle, separator, lipgloss.Color("6"))
}

func renderConfirmDelete(m model, width int, height int) string {
	rowWidth := max(10, width-4)
	headerStyle := lipgloss.NewStyle().Bold(true).Width(rowWidth).Foreground(lipgloss.Color("1"))
	alertStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("1")).Width(rowWidth)
	muted := lipgloss.NewStyle().Foreground(lipgloss.Color("8")).Width(rowWidth)
	plain := lipgloss.NewStyle().Width(rowWidth).Foreground(lipgloss.Color("7"))

	selected := selectedPaneIDs(m)
	if len(selected) == 0 && m.selectedPaneID != "" {
		selected = []string{m.selectedPaneID}
	}
	count := len(selected)

	lines := []string{}
	lines = append(lines, alertStyle.Render("Delete panes"))
	lines = append(lines, muted.Render(fmt.Sprintf("This will kill %d pane(s).", count)))
	if count > 0 {
		previewIDs := selected
		if len(previewIDs) > 6 {
			previewIDs = previewIDs[:6]
		}
		lines = append(lines, plain.Render("Targets:"))
		for _, paneID := range previewIDs {
			label := deletePaneLabel(m.state, paneID)
			lines = append(lines, plain.Render("  - "+label))
			lines = append(lines, muted.Render("      "+paneID))
		}
		if len(selected) > len(previewIDs) {
			lines = append(lines, muted.Render(fmt.Sprintf("  ...and %d more", len(selected)-len(previewIDs))))
		}
	}
	lines = append(lines, "")
	lines = append(lines, plain.Render("Confirm: y = delete, n = cancel"))

	visible := sliceRows(lines, 0, max(1, height-2))
	content := lipgloss.JoinVertical(lipgloss.Left, visible...)
	separator := mutedSeparator(rowWidth)
	return modalFrame("Confirm Delete", content, width, height, headerStyle, separator, lipgloss.Color("1"))
}

func renderNewSession(m model, width int, height int) string {
	rowWidth := max(10, width-4)
	headerStyle := lipgloss.NewStyle().Bold(true).Width(rowWidth).Foreground(lipgloss.Color("2"))
	accentStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("2")).Width(rowWidth)
	muted := lipgloss.NewStyle().Foreground(lipgloss.Color("8")).Width(rowWidth)
	plain := lipgloss.NewStyle().Width(rowWidth).Foreground(lipgloss.Color("7"))

	name := strings.TrimSpace(m.input)
	label := "(auto name)"
	if name != "" {
		label = name
	}

	lines := []string{}
	lines = append(lines, accentStyle.Render("New session"))
	lines = append(lines, plain.Render("Name: "+label))
	lines = append(lines, muted.Render("Leave blank to let tmux choose."))
	lines = append(lines, "")
	lines = append(lines, plain.Render("Press enter to create or esc to cancel."))

	visible := sliceRows(lines, 0, max(1, height-2))
	content := lipgloss.JoinVertical(lipgloss.Left, visible...)
	separator := mutedSeparator(rowWidth)
	return modalFrame("Create Session", content, width, height, headerStyle, separator, lipgloss.Color("2"))
}

func modalFrame(title string, content string, width int, height int, headerStyle lipgloss.Style, separator string, accent lipgloss.Color) string {
	rowWidth := max(10, width-2)
	frame := lipgloss.NewStyle().
		Width(width).
		Height(height).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(accent).
		Padding(0, 1)
	if separator == "" {
		separator = mutedSeparator(rowWidth)
	}
	header := headerStyle.Render(title)
	return frame.Render(lipgloss.JoinVertical(lipgloss.Left, header, separator, content))
}

func renderModalForMode(m model, availableWidth int) (string, bool) {
	modalWidth := min(max(48, availableWidth/2), max(48, availableWidth-10))
	modalHeight := min(12, max(8, (m.height-6)/2))
	switch m.mode {
	case ModePickWindow:
		windows := windowChoicesForMove(m)
		return renderChoiceList("Move Pane -> Window", windows, m.targetIndex, modalWidth, modalHeight), true
	case ModePickSession:
		sessions := sessionChoicesForMove(m)
		return renderChoiceList("Move Window -> Session", sessions, m.targetIndex, modalWidth, modalHeight), true
	case ModeNewSession:
		return renderNewSession(m, modalWidth, modalHeight), true
	case ModeConfirmDelete:
		return renderConfirmDelete(m, modalWidth, modalHeight), true
	default:
		return "", false
	}
}

func dimBody(body string) string {
	return lipgloss.NewStyle().Foreground(lipgloss.Color("244")).Render(body)
}

func overlayModal(base string, modal string, width int, height int) string {
	if width <= 0 || height <= 0 {
		return base
	}
	baseLines := strings.Split(base, "\n")
	if len(baseLines) < height {
		for len(baseLines) < height {
			baseLines = append(baseLines, "")
		}
	} else if len(baseLines) > height {
		baseLines = baseLines[:height]
	}
	modalLines := strings.Split(modal, "\n")
	if len(modalLines) > height {
		modalLines = modalLines[:height]
	}
	modalWidth := 0
	for _, line := range modalLines {
		lineWidth := ansi.StringWidth(line)
		if lineWidth > modalWidth {
			modalWidth = lineWidth
		}
	}
	if modalWidth <= 0 || len(modalLines) == 0 {
		return strings.Join(baseLines, "\n")
	}
	startRow := max(0, (height-len(modalLines))/2)
	startCol := max(0, (width-modalWidth)/2)
	for i, line := range modalLines {
		row := startRow + i
		if row < 0 || row >= len(baseLines) {
			continue
		}
		baseLine := ansi.Strip(baseLines[row])
		baseLine = padRight(baseLine, width)
		left := sliceByWidth(baseLine, 0, startCol)
		right := sliceByWidth(baseLine, startCol+modalWidth, width-startCol-modalWidth)
		baseLines[row] = left + line + right
	}
	return strings.Join(baseLines, "\n")
}

func sliceByWidth(s string, start int, width int) string {
	if width <= 0 {
		return ""
	}
	if start < 0 {
		start = 0
	}
	if start > runewidth.StringWidth(s) {
		return ""
	}
	trimmed := runewidth.Truncate(s, start+width, "")
	return runewidth.Truncate(trimmed[start:], width, "")
}

func deletePaneLabel(state TmuxState, paneID string) string {
	var pane Pane
	for _, p := range state.Panes {
		if p.ID == paneID {
			pane = p
			break
		}
	}
	if pane.ID == "" {
		return "unknown pane"
	}
	windowName := ""
	windowIndex := ""
	for _, w := range state.Windows {
		if w.ID == pane.WindowID {
			windowName = w.Name
			windowIndex = w.Index
			break
		}
	}
	sessionName := ""
	for _, s := range state.Sessions {
		if s.ID == pane.SessionID {
			sessionName = s.Name
			break
		}
	}
	parts := []string{}
	if sessionName != "" || windowName != "" {
		windowLabel := windowName
		if windowIndex != "" {
			windowLabel = fmt.Sprintf("%s:%s", windowIndex, windowName)
		}
		if sessionName != "" {
			parts = append(parts, fmt.Sprintf("%s / %s", sessionName, windowLabel))
		} else {
			parts = append(parts, windowLabel)
		}
	}
	if pane.Command != "" {
		parts = append(parts, pane.Command)
	}
	if pane.Path != "" {
		parts = append(parts, pane.Path)
	}
	if pane.Title != "" {
		parts = append(parts, fmt.Sprintf("(%s)", pane.Title))
	}
	if len(parts) == 0 {
		return paneID
	}
	return strings.Join(parts, " — ")
}

func renderPaneList(state TmuxState, selectedPaneID string, scroll int, width int, height int, selectedPanes map[string]bool, selectedWindows map[string]bool, activeSessionID string, activeWindowID string) string {
	if selectedWindows == nil {
		selectedWindows = map[string]bool{}
		for _, pane := range state.Panes {
			if selectedPanes != nil && selectedPanes[pane.ID] {
				selectedWindows[pane.WindowID] = true
			}
		}
	}
	tree := buildTreeRows(state, selectedPaneID, width, selectedPanes, selectedWindows, activeSessionID, activeWindowID)
	visible := sliceRows(tree.rows, scroll, max(1, height-2))
	content := lipgloss.JoinVertical(lipgloss.Left, visible...)
	separator := mutedSeparator(max(1, width-2))
	return panelBlock(width, height, lipgloss.JoinVertical(lipgloss.Left, tree.header, separator, content))
}

type treeRows struct {
	header      string
	rows        []string
	selectedRow int
}

func buildTreeRows(state TmuxState, selectedPaneID string, width int, selectedPanes map[string]bool, selectedWindows map[string]bool, activeSessionID string, activeWindowID string) treeRows {
	rowWidth := max(10, width-2)
	normalStyle := lipgloss.NewStyle().Width(rowWidth)
	selectedStyle := lipgloss.NewStyle().Width(rowWidth).Bold(true).Foreground(lipgloss.Color("2"))
	headerStyle := lipgloss.NewStyle().Bold(true).Width(rowWidth)
	windowStyle := lipgloss.NewStyle().Bold(true).Width(rowWidth).Foreground(lipgloss.Color("6"))
	sessionStyle := lipgloss.NewStyle().Bold(true).Width(rowWidth).Foreground(lipgloss.Color("4"))

	panesByWindow := make(map[string][]Pane)
	for _, pane := range state.Panes {
		panesByWindow[pane.WindowID] = append(panesByWindow[pane.WindowID], pane)
	}

	windowsBySession := make(map[string][]Window)
	for _, window := range state.Windows {
		windowsBySession[window.SessionID] = append(windowsBySession[window.SessionID], window)
	}

	for sessionID, windows := range windowsBySession {
		sort.SliceStable(windows, func(i, j int) bool {
			return windows[i].IndexNum < windows[j].IndexNum
		})
		windowsBySession[sessionID] = windows
	}

	for windowID, panes := range panesByWindow {
		sort.SliceStable(panes, func(i, j int) bool {
			return panes[i].IndexNum < panes[j].IndexNum
		})
		panesByWindow[windowID] = panes
	}

	sessions := append([]Session(nil), state.Sessions...)
	sort.SliceStable(sessions, func(i, j int) bool {
		return sessions[i].Name < sessions[j].Name
	})

	rows := make([]string, 0, len(state.Panes)+len(state.Windows)+len(state.Sessions))
	selectedRow := -1
	for _, session := range sessions {
		sessionPrefix := "  "
		if activeSessionID != "" && session.ID == activeSessionID {
			sessionPrefix = "• "
		}
		sessionRow := truncateRow(fmt.Sprintf("%s%s", sessionPrefix, session.Name), rowWidth)
		rows = append(rows, sessionStyle.Render(sessionRow))
		for _, window := range windowsBySession[session.ID] {
			windowMarker := " "
			if selectedWindows != nil && selectedWindows[window.ID] {
				windowMarker = "*"
			}
			windowPrefix := " "
			if activeWindowID != "" && window.ID == activeWindowID {
				windowPrefix = "•"
			}
			windowRow := truncateRow(fmt.Sprintf("%s %s %s:%s", windowPrefix, windowMarker, window.Index, window.Name), rowWidth)
			rows = append(rows, windowStyle.Render(windowRow))
			panes := panesByWindow[window.ID]
			for _, pane := range panes {
				paneMarker := " "
				if selectedPanes != nil && selectedPanes[pane.ID] {
					paneMarker = "*"
				}
				row := fmt.Sprintf("    %s %s  %s", paneMarker, pane.Command, pane.Path)
				row = truncateRow(row, rowWidth)
				if pane.ID == selectedPaneID {
					selectedRow = len(rows)
					rows = append(rows, selectedStyle.Render(row))
				} else {
					rows = append(rows, normalStyle.Render(row))
				}
			}
		}
	}

	return treeRows{
		header:      headerStyle.Render("Panes"),
		rows:        rows,
		selectedRow: selectedRow,
	}
}

func renderPreview(text string, err error, width int, height int) string {
	headerStyle := lipgloss.NewStyle().Bold(true)
	style := lipgloss.NewStyle().Width(max(1, width-2))
	if err != nil {
		return panelBlock(width, height, lipgloss.JoinVertical(lipgloss.Left, headerStyle.Render("Preview"), mutedSeparator(max(1, width-2)), style.Render(fmt.Sprintf("Preview error: %s", err))))
	}
	if strings.TrimSpace(text) == "" {
		return panelBlock(width, height, lipgloss.JoinVertical(lipgloss.Left, headerStyle.Render("Preview"), mutedSeparator(max(1, width-2)), style.Render("Preview unavailable")))
	}
	content := truncatePreview(text, max(1, width-2), max(1, height-2))
	separator := mutedSeparator(max(1, width-2))
	return panelBlock(width, height, lipgloss.JoinVertical(lipgloss.Left, headerStyle.Render("Preview"), separator, style.Render(content)))
}

func renderPreviewSelf(width int, height int) string {
	headerStyle := lipgloss.NewStyle().Bold(true)
	separator := mutedSeparator(max(1, width-2))
	label := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("6")).
		Foreground(lipgloss.Color("7")).
		Background(lipgloss.Color("237")).
		Padding(0, 1).
		Render("tmux-mover active")
	content := lipgloss.NewStyle().Width(max(1, width-2)).Render(label)
	return panelBlock(width, height, lipgloss.JoinVertical(lipgloss.Left, headerStyle.Render("Preview"), separator, content))
}

func currentPaneID(m model) string {
	order := activeOrder(m)
	if len(order) == 0 || m.selectedIndex >= len(order) {
		return ""
	}
	return order[m.selectedIndex]
}

func effectiveSelectedPaneID(order []string, selectedID string, lastSelectedID string, selectedIndex int) string {
	if selectedID != "" {
		if _, ok := findPaneIndex(order, selectedID); ok {
			return selectedID
		}
	}
	if lastSelectedID != "" {
		if _, ok := findPaneIndex(order, lastSelectedID); ok {
			return lastSelectedID
		}
	}
	if selectedIndex >= 0 && selectedIndex < len(order) {
		return order[selectedIndex]
	}
	return ""
}

func normalizeSelectedIndex(m model) model {
	order := activeOrder(m)
	if len(order) == 0 {
		m.selectedIndex = 0
		return m
	}
	effectiveID := effectiveSelectedPaneID(order, m.selectedPaneID, m.lastSelectedID, m.selectedIndex)
	if idx, ok := findPaneIndex(order, effectiveID); ok {
		m.selectedIndex = idx
		return m
	}
	if m.selectedIndex >= len(order) {
		m.selectedIndex = len(order) - 1
	}
	return m
}

func findPaneIndex(order []string, paneID string) (int, bool) {
	if paneID == "" {
		return -1, false
	}
	for idx, id := range order {
		if id == paneID {
			return idx, true
		}
	}
	return -1, false
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func truncateRow(s string, width int) string {
	if width <= 0 {
		return ""
	}
	if runewidth.StringWidth(s) <= width {
		return s
	}
	if width <= 3 {
		return runewidth.Truncate(s, width, "")
	}
	return runewidth.Truncate(s, width, "...")
}

func sliceRows(rows []string, start int, maxRows int) []string {
	if len(rows) <= maxRows {
		return rows
	}
	if start < 0 {
		start = 0
	}
	end := start + maxRows
	if end > len(rows) {
		end = len(rows)
		start = max(0, end-maxRows)
	}
	return rows[start:end]
}

func ensureVisible(m model) model {
	if len(m.state.Panes) == 0 {
		m.scroll = 0
		return m
	}
	listWidth, _, listHeight, _, _, _, _, _, _ := layoutDims(m, max(1, m.width-2))
	visibleRows := max(1, listHeight-2)
	state := activeState(m)
	effectiveID := effectiveSelectedPaneID(activeOrder(m), m.selectedPaneID, m.lastSelectedID, m.selectedIndex)
	tree := buildTreeRows(state, effectiveID, listWidth, m.selectedPanes, nil, m.selfSessionID, m.selfWindowID)
	selectedRow := tree.selectedRow
	if selectedRow < 0 {
		selectedRow = 0
	}
	if selectedRow < m.scroll {
		m.scroll = selectedRow
	}
	if selectedRow >= m.scroll+visibleRows {
		m.scroll = selectedRow - visibleRows + 1
	}
	maxScroll := max(0, len(tree.rows)-visibleRows)
	if m.scroll > maxScroll {
		m.scroll = maxScroll
	}
	return m
}

func syncSelection(m model) model {
	order := activeOrder(m)
	if len(order) == 0 {
		m.selectedIndex = 0
		m.selectedPaneID = ""
		return m
	}
	effectiveID := effectiveSelectedPaneID(order, m.selectedPaneID, m.lastSelectedID, m.selectedIndex)
	if effectiveID == "" {
		m.selectedIndex = 0
		m.selectedPaneID = order[0]
		m.lastSelectedID = m.selectedPaneID
		return m
	}
	if idx, ok := findPaneIndex(order, effectiveID); ok {
		m.selectedIndex = idx
		m.selectedPaneID = effectiveID
		m.lastSelectedID = m.selectedPaneID
		return m
	}
	if m.selectedIndex < 0 {
		m.selectedIndex = 0
	}
	if m.selectedIndex >= len(order) {
		m.selectedIndex = len(order) - 1
	}
	m.selectedPaneID = order[m.selectedIndex]
	m.lastSelectedID = m.selectedPaneID
	return m
}

func layoutDims(m model, availableWidth int) (listWidth int, previewWidth int, listHeight int, previewHeight int, keyBarHeight int, vertical bool, gapWidth int, gapVertical int, gapTopBottom int) {
	contentHeight := max(12, m.height-4)
	keyBarHeight = 3
	gapWidth = 2
	gapVertical = 1
	gapTopBottom = 1
	minPanelWidth := 30
	mainHeight := max(6, contentHeight-keyBarHeight-gapTopBottom)
	if availableWidth < minPanelWidth*2+gapWidth {
		vertical = true
		mainHeight = max(6, contentHeight-keyBarHeight-gapTopBottom-gapVertical)
		listWidth, previewWidth, listHeight, previewHeight = layoutDimsVertical(m, availableWidth, mainHeight)
		return
	}

	vertical = false
	listWidth = max(minPanelWidth, availableWidth/2)
	previewWidth = availableWidth - listWidth - gapWidth
	if previewWidth < minPanelWidth {
		previewWidth = minPanelWidth
		listWidth = availableWidth - previewWidth - gapWidth
	}
	listHeight = mainHeight
	previewHeight = mainHeight
	return
}

func layoutDimsVertical(m model, availableWidth int, mainHeight int) (listWidth int, previewWidth int, listHeight int, previewHeight int) {
	listWidth = max(30, availableWidth)
	previewWidth = listWidth
	listHeight = max(6, mainHeight/2)
	previewHeight = max(6, mainHeight-listHeight)
	return
}

func renderKeyBar(keys Keymap, width int, height int, filterInput string, filtering bool, status string) string {
	if height <= 0 {
		return ""
	}
	rowWidth := max(10, width-2)
	muted := lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	lines := keyHintsStyled(normalizeKeymap(keys), rowWidth)
	if len(lines) == 0 {
		lines = []string{"(no keys)"}
	}
	if filtering || filterInput != "" {
		filterLabel := lipgloss.NewStyle().Foreground(lipgloss.Color("6")).Bold(true).Render("/")
		query := filterInput
		if strings.TrimSpace(query) == "" {
			query = "(type to filter)"
		}
		filterLine := fmt.Sprintf("%s %s", filterLabel, query)
		lines = append([]string{filterLine}, lines...)
	}
	if strings.TrimSpace(status) != "" {
		statusLine := fmt.Sprintf("→ %s", status)
		statusStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("15")).Bold(true)
		lines = append([]string{statusStyle.Render(statusLine)}, lines...)
	}
	visible := sliceRows(lines, 0, max(1, height))
	content := lipgloss.JoinVertical(lipgloss.Left, visible...)
	panel := lipgloss.NewStyle().Width(width).Height(height).Padding(0, 1)
	return panel.Render(muted.Render(content))
}

func panelBlock(width int, height int, content string) string {
	panel := lipgloss.NewStyle().Width(width).Height(height).Padding(0, 1)
	return panel.Render(content)
}

func mutedSeparator(width int) string {
	if width <= 0 {
		return ""
	}
	return lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(strings.Repeat("─", width))
}

func truncatePreview(text string, width int, height int) string {
	if width <= 0 || height <= 0 {
		return ""
	}
	lines := strings.Split(strings.TrimRight(text, "\n"), "\n")
	if len(lines) > height {
		lines = lines[:height]
	}
	for i, line := range lines {
		lines[i] = ansi.Truncate(line, width, "") + "\x1b[0m"
	}
	return strings.Join(lines, "\n")
}

type ActionType string

const (
	ActionPaneMove   ActionType = "pane_move"
	ActionWindowMove ActionType = "window_move"
)

type StagedAction struct {
	Type     ActionType
	SourceID string
	TargetID string
	NewName  string
}

func renderActionsPanel(actions []StagedAction, mode Mode, input string, status string, filterInput string, filtering bool, countBuffer string, keys Keymap, width int, height int) string {
	headerStyle := lipgloss.NewStyle().Bold(true)
	rowWidth := max(10, width-4)
	rows := make([]string, 0, len(actions)+6)
	prompt := ""
	switch mode {
	case ModePickWindow:
		prompt = "select target window"
	case ModePickSession:
		prompt = "select target session"
	case ModeNewSession:
		prompt = fmt.Sprintf("new session name (optional): %s", input)
	case ModeConfirmDelete:
		prompt = "confirm delete (y/n)"
	}
	label := lipgloss.NewStyle().Foreground(lipgloss.Color("7")).Bold(true)
	muted := lipgloss.NewStyle().Foreground(lipgloss.Color("8"))

	statusLine := status
	if statusLine == "" {
		statusLine = "idle"
	}
	rows = append(rows, truncateANSI(label.Render("Status")+"  "+muted.Render(statusLine), rowWidth))
	if countBuffer != "" {
		rows = append(rows, truncateANSI(label.Render("Count")+"   "+muted.Render(countBuffer), rowWidth))
	}
	if filtering || filterInput != "" {
		rows = append(rows, truncateANSI(label.Render("Filter")+"  "+muted.Render(filterInput), rowWidth))
	}
	if prompt != "" {
		rows = append(rows, truncateANSI(label.Render("Mode")+"    "+muted.Render(prompt), rowWidth))
	}
	rows = append(rows, sectionRule(rowWidth))

	rows = append(rows, truncateANSI(muted.Render("Keys"), rowWidth))
	keyLines := keyHintsStyled(normalizeKeymap(keys), rowWidth)
	if len(keyLines) == 0 {
		rows = append(rows, truncateANSI(muted.Render("(no keys)"), rowWidth))
	} else {
		for _, hint := range keyLines {
			rows = append(rows, truncateANSI(hint, rowWidth))
		}
	}

	rows = append(rows, sectionRule(rowWidth))
	rows = append(rows, truncateANSI(muted.Render("Recent"), rowWidth))
	if len(actions) == 0 {
		rows = append(rows, truncateANSI(muted.Render("(no actions yet)"), rowWidth))
	} else {
		for _, action := range actions {
			rows = append(rows, truncateRow("- "+formatAction(action), rowWidth))
		}
	}
	visible := sliceRows(rows, 0, max(1, height-2))
	content := lipgloss.JoinVertical(lipgloss.Left, visible...)
	box := lipgloss.NewStyle().
		Width(width).
		Height(height).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("7")).
		Padding(0, 1)
	return box.Render(lipgloss.JoinVertical(lipgloss.Left, headerStyle.Render("Actions"), content))
}

func formatAction(action StagedAction) string {
	switch action.Type {
	case ActionPaneMove:
		return fmt.Sprintf("move pane %s -> %s", action.SourceID, action.TargetID)
	case ActionWindowMove:
		return fmt.Sprintf("move window %s -> %s", action.SourceID, action.TargetID)
	default:
		return "unknown action"
	}
}

func keyMatches(msg tea.KeyMsg, keys []string) bool {
	if len(keys) == 0 {
		return false
	}
	value := msg.String()
	for _, key := range keys {
		if value == key {
			return true
		}
		if matchesKeyType(msg, key) {
			return true
		}
	}
	return false
}

func matchesKeyType(msg tea.KeyMsg, key string) bool {
	switch key {
	case "up":
		return msg.Type == tea.KeyUp
	case "down":
		return msg.Type == tea.KeyDown
	case "left":
		return msg.Type == tea.KeyLeft
	case "right":
		return msg.Type == tea.KeyRight
	case "enter":
		return msg.Type == tea.KeyEnter
	case "backspace":
		return msg.Type == tea.KeyBackspace
	case "esc":
		return msg.Type == tea.KeyEsc
	default:
		return false
	}
}

func keyHintsStyled(keys Keymap, width int) []string {
	keyStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("7"))
	labelStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	item := func(key string, label string) string {
		if key == "" {
			return ""
		}
		return keyStyle.Render(key) + " " + labelStyle.Render(label)
	}

	items := []string{
		item("↑/↓/j/k", "move selection"),
		item("/", "filter"),
		item("0-9", "count"),
		item("enter", "jump to pane"),
		item("alt+j/alt+k", "swap pane"),
		item("alt+J/alt+K", "swap window"),
		item("space", "select pane"),
		item("tab", "select+next"),
		item("shift+tab", "select+prev"),
		item("c", "clear selection"),
		item(joinKeys(keys.BreakPane), "break pane"),
		item(joinKeys(keys.CreateSession), "new session"),
		item(joinKeys(keys.DeletePanes), "delete panes"),
		item(joinKeys(keys.MovePane), "move pane"),
		item(joinKeys(keys.MoveWindow), "move window"),
		item(joinKeys(keys.Cancel), "cancel"),
		item(joinKeys(keys.Quit), "quit"),
	}

	return wrapLegendItems(items, width)
}

func wrapLegendItems(items []string, width int) []string {
	if width <= 0 {
		return nil
	}
	cleanItems := make([]string, 0, len(items))
	for _, item := range items {
		if item != "" {
			cleanItems = append(cleanItems, item)
		}
	}
	if len(cleanItems) == 0 {
		return nil
	}

	sep := " " + lipgloss.NewStyle().Foreground(lipgloss.Color("8")).Render("•") + " "
	lines := []string{}
	current := ""
	currentWidth := 0
	sepWidth := ansi.StringWidth(sep)
	for _, item := range cleanItems {
		itemWidth := ansi.StringWidth(item)
		if current == "" {
			current = item
			currentWidth = itemWidth
			continue
		}
		if currentWidth+sepWidth+itemWidth <= width {
			current += sep + item
			currentWidth += sepWidth + itemWidth
		} else {
			lines = append(lines, current)
			current = item
			currentWidth = itemWidth
		}
	}
	if current != "" {
		lines = append(lines, current)
	}
	return lines
}

func normalizeKeymap(keys Keymap) Keymap {
	if joinKeys(keys.MoveDown) == "" &&
		joinKeys(keys.MoveUp) == "" &&
		joinKeys(keys.MovePane) == "" &&
		joinKeys(keys.MoveWindow) == "" &&
		joinKeys(keys.Cancel) == "" &&
		joinKeys(keys.Quit) == "" {
		return defaultKeymap()
	}
	return keys
}

func truncateANSI(s string, width int) string {
	if width <= 0 {
		return ""
	}
	return ansi.Truncate(s, width, "")
}

func activeState(m model) TmuxState {
	if m.filterActive && strings.TrimSpace(m.filterInput) != "" {
		return filterState(m.state, m.filterInput)
	}
	return m.state
}

func activeOrder(m model) []string {
	return buildPaneOrder(activeState(m))
}

func consumeCount(buffer *string, fallback int) int {
	if buffer == nil || *buffer == "" {
		return fallback
	}
	count := 0
	for _, r := range *buffer {
		if r < '0' || r > '9' {
			count = 0
			break
		}
		count = count*10 + int(r-'0')
	}
	*buffer = ""
	if count <= 0 {
		return fallback
	}
	return count
}

func filterState(state TmuxState, query string) TmuxState {
	if strings.TrimSpace(query) == "" {
		return state
	}
	query = strings.ToLower(query)
	match := func(s string) bool {
		return strings.Contains(strings.ToLower(s), query)
	}
	panes := []Pane{}
	windowHasPane := map[string]bool{}
	for _, pane := range state.Panes {
		if match(pane.ID) || match(pane.Command) || match(pane.Path) || match(pane.Title) {
			panes = append(panes, pane)
			windowHasPane[pane.WindowID] = true
		}
	}
	windows := []Window{}
	windowSet := map[string]bool{}
	for _, window := range state.Windows {
		if windowHasPane[window.ID] || match(window.Name) || match(window.Index) {
			windows = append(windows, window)
			windowSet[window.ID] = true
		}
	}
	sessionHasWindow := map[string]bool{}
	for _, window := range windows {
		sessionHasWindow[window.SessionID] = true
	}
	sessions := []Session{}
	for _, session := range state.Sessions {
		if sessionHasWindow[session.ID] || match(session.Name) {
			sessions = append(sessions, session)
		}
	}
	// Keep panes whose window is still present
	filteredPanes := []Pane{}
	for _, pane := range panes {
		if windowSet[pane.WindowID] {
			filteredPanes = append(filteredPanes, pane)
		}
	}
	return TmuxState{Sessions: sessions, Windows: windows, Panes: filteredPanes}
}

func ensureSelectionMaps(m model) model {
	if m.selectedPanes == nil {
		m.selectedPanes = map[string]bool{}
	}
	return m
}

func pruneSelectedPanes(selected map[string]bool, panes []Pane) map[string]bool {
	if selected == nil {
		return map[string]bool{}
	}
	valid := map[string]bool{}
	for _, pane := range panes {
		if selected[pane.ID] {
			valid[pane.ID] = true
		}
	}
	return valid
}

func togglePaneSelection(m model) (tea.Model, tea.Cmd) {
	if m.selectedPaneID == "" {
		return m, nil
	}
	m = ensureSelectionMaps(m)
	// window selection derived from selected panes
	if m.selectedPanes[m.selectedPaneID] {
		delete(m.selectedPanes, m.selectedPaneID)
	} else {
		m.selectedPanes[m.selectedPaneID] = true
	}
	return m, nil
}

func selectedPaneIDs(m model) []string {
	if len(m.selectedPanes) == 0 {
		return nil
	}
	ids := []string{}
	for _, id := range m.paneOrder {
		if m.selectedPanes[id] {
			ids = append(ids, id)
		}
	}
	return ids
}

func deletePaneCount(m model) int {
	selected := selectedPaneIDs(m)
	if len(selected) > 0 {
		return len(selected)
	}
	if m.selectedPaneID != "" {
		return 1
	}
	return 0
}

func confirmDeletePanes(m model) (tea.Model, tea.Cmd) {
	selected := selectedPaneIDs(m)
	if len(selected) == 0 && m.selectedPaneID != "" {
		selected = []string{m.selectedPaneID}
	}
	if len(selected) == 0 {
		m.mode = ModeList
		m.status = "No pane selected"
		return m, nil
	}
	deleted := 0
	for _, paneID := range selected {
		if err := applyPaneKill(paneID); err != nil {
			m.mode = ModeList
			m.status = fmt.Sprintf("Error: %s", err)
			return m, nil
		}
		deleted++
	}
	m.mode = ModeList
	m.selectedPanes = map[string]bool{}
	m.status = fmt.Sprintf("Deleted %d pane(s)", deleted)
	return m, loadStateCmd()
}

func selectedWindowIDsFromPanes(m model) []string {
	if len(m.selectedPanes) == 0 {
		return nil
	}
	windowSet := map[string]bool{}
	for _, pane := range m.state.Panes {
		if m.selectedPanes[pane.ID] {
			windowSet[pane.WindowID] = true
		}
	}
	ids := []string{}
	for _, window := range orderedWindows(m.state) {
		if windowSet[window.ID] {
			ids = append(ids, window.ID)
		}
	}
	return ids
}

func movePanesToWindow(m model, paneIDs []string, windowID string) (int, int, string, string, error) {
	moved := 0
	skipped := 0
	newSelfWindowID := ""
	newSelfSessionID := ""
	for _, paneID := range paneIDs {
		if windowIDForPane(m.state, paneID) == windowID {
			skipped++
			continue
		}
		action := StagedAction{Type: ActionPaneMove, SourceID: paneID, TargetID: windowID}
		if err := applyPaneMove(action); err != nil {
			return moved, skipped, newSelfWindowID, newSelfSessionID, err
		}
		moved++
		if paneID == m.selfPaneID {
			newSelfWindowID = windowID
			newSelfSessionID = sessionIDForWindow(m.state, windowID)
		}
	}
	return moved, skipped, newSelfWindowID, newSelfSessionID, nil
}

func moveWindowsToSession(m model, windowIDs []string, sessionID string) (int, int, string, error) {
	moved := 0
	skipped := 0
	newSelfSessionID := ""
	for _, windowID := range windowIDs {
		if sessionIDForWindow(m.state, windowID) == sessionID {
			skipped++
			continue
		}
		action := StagedAction{Type: ActionWindowMove, SourceID: windowID, TargetID: sessionID}
		if err := applyWindowMove(action); err != nil {
			return moved, skipped, newSelfSessionID, err
		}
		moved++
		if windowID == m.selfWindowID {
			newSelfSessionID = sessionID
		}
	}
	return moved, skipped, newSelfSessionID, nil
}

func padRight(s string, width int) string {
	if width <= 0 {
		return ""
	}
	if runewidth.StringWidth(s) >= width {
		return s
	}
	return s + strings.Repeat(" ", width-runewidth.StringWidth(s))
}

func padRightANSI(s string, width int) string {
	if width <= 0 {
		return ""
	}
	current := ansi.StringWidth(s)
	if current >= width {
		return s
	}
	return s + strings.Repeat(" ", width-current)
}

func sectionRule(width int) string {
	return strings.Repeat("─", max(1, width-2))
}

func joinKeys(keys []string) string {
	if len(keys) == 0 {
		return ""
	}
	return strings.Join(keys, "/")
}

func refocusSelf(paneID string, sessionID string, windowID string, clientID string) error {
	if paneID == "" {
		return nil
	}
	if sessionID != "" {
		if clientID != "" {
			_, _ = tmuxOutput("switch-client", "-c", clientID, "-t", sessionID)
		} else {
			_, _ = tmuxOutput("switch-client", "-t", sessionID)
		}
	}
	if windowID != "" {
		_, _ = tmuxOutput("select-window", "-t", windowID)
	}
	_, err := tmuxOutput("select-pane", "-t", paneID)
	return err
}

func refocusPane(m model, paneID string) error {
	if paneID == "" {
		return nil
	}
	sessionID := sessionIDForPane(m.state, paneID)
	windowID := windowIDForPane(m.state, paneID)
	return refocusSelf(paneID, sessionID, windowID, m.selfClientID)
}

func buildPaneOrder(state TmuxState) []string {
	panesByWindow := make(map[string][]Pane)
	for _, pane := range state.Panes {
		panesByWindow[pane.WindowID] = append(panesByWindow[pane.WindowID], pane)
	}

	windowsBySession := make(map[string][]Window)
	for _, window := range state.Windows {
		windowsBySession[window.SessionID] = append(windowsBySession[window.SessionID], window)
	}

	for sessionID, windows := range windowsBySession {
		sort.SliceStable(windows, func(i, j int) bool {
			return windows[i].IndexNum < windows[j].IndexNum
		})
		windowsBySession[sessionID] = windows
	}

	for windowID, panes := range panesByWindow {
		sort.SliceStable(panes, func(i, j int) bool {
			return panes[i].IndexNum < panes[j].IndexNum
		})
		panesByWindow[windowID] = panes
	}

	sessions := append([]Session(nil), state.Sessions...)
	sort.SliceStable(sessions, func(i, j int) bool {
		return sessions[i].Name < sessions[j].Name
	})

	order := make([]string, 0, len(state.Panes))
	for _, session := range sessions {
		for _, window := range windowsBySession[session.ID] {
			for _, pane := range panesByWindow[window.ID] {
				order = append(order, pane.ID)
			}
		}
	}

	return order
}

func selectPaneIndex(order []string, paneID string, fallback int) int {
	if paneID != "" {
		for idx, id := range order {
			if id == paneID {
				return idx
			}
		}
	}
	if fallback >= 0 && fallback < len(order) {
		return fallback
	}
	return 0
}
