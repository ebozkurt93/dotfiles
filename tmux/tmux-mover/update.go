package main

import (
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

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
	return tea.Tick(100*time.Millisecond, func(time.Time) tea.Msg {
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

func togglePaneSelection(m model) (tea.Model, tea.Cmd) {
	if m.selectedPaneID == "" {
		return m, nil
	}
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
	switchedSessionID := ""
	if targetSession, needed := fallbackSessionBeforeDelete(m, selected); needed {
		if targetSession == "" {
			m.mode = ModeList
			m.status = "Cannot delete all panes in active session"
			return m, nil
		}
		if err := switchClientToSession(targetSession, m.selfClientID); err != nil {
			m.mode = ModeList
			m.status = fmt.Sprintf("Error: %s", err)
			return m, nil
		}
		m.selfSessionID = targetSession
		switchedSessionID = targetSession
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
	if switchedSessionID != "" {
		switchedSessionName := sessionNameByID(m.state, switchedSessionID)
		if switchedSessionName == "" {
			switchedSessionName = switchedSessionID
		}
		m.status = fmt.Sprintf("Switched to %s, deleted %d pane(s)", switchedSessionName, deleted)
	} else {
		m.status = fmt.Sprintf("Deleted %d pane(s)", deleted)
	}
	return m, loadStateCmd()
}

func sessionNameByID(state TmuxState, sessionID string) string {
	for _, session := range state.Sessions {
		if session.ID == sessionID {
			return session.Name
		}
	}
	return ""
}

func fallbackSessionBeforeDelete(m model, selected []string) (string, bool) {
	if m.selfSessionID == "" || len(selected) == 0 {
		return "", false
	}
	selectedSet := map[string]bool{}
	for _, paneID := range selected {
		selectedSet[paneID] = true
	}
	remainingInSelf := 0
	for _, pane := range m.state.Panes {
		if pane.SessionID == m.selfSessionID && !selectedSet[pane.ID] {
			remainingInSelf++
		}
	}
	if remainingInSelf > 0 {
		return "", false
	}
	sessionHasRemainingPanes := map[string]bool{}
	for _, pane := range m.state.Panes {
		if !selectedSet[pane.ID] {
			sessionHasRemainingPanes[pane.SessionID] = true
		}
	}
	sessions := orderedSessions(m.state)
	selfIndex := -1
	for i, session := range sessions {
		if session.ID == m.selfSessionID {
			selfIndex = i
			break
		}
	}
	if selfIndex >= 0 {
		for i := selfIndex - 1; i >= 0; i-- {
			sessionID := sessions[i].ID
			if sessionHasRemainingPanes[sessionID] {
				return sessionID, true
			}
		}
	}
	for _, session := range sessions {
		if session.ID != m.selfSessionID && sessionHasRemainingPanes[session.ID] {
			return session.ID, true
		}
	}
	return "", true
}
