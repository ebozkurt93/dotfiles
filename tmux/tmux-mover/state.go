package main

import (
	"sort"
	"strings"
)

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
	directSessionSet := map[string]bool{}
	for _, session := range state.Sessions {
		if match(session.ID) || match(session.Name) {
			directSessionSet[session.ID] = true
		}
	}

	windowSet := map[string]bool{}
	for _, window := range state.Windows {
		if directSessionSet[window.SessionID] || match(window.ID) || match(window.Name) || match(window.Index) {
			windowSet[window.ID] = true
		}
	}

	paneSet := map[string]bool{}
	for _, pane := range state.Panes {
		if windowSet[pane.WindowID] || directSessionSet[pane.SessionID] || match(pane.ID) || match(pane.Command) || match(pane.Path) || match(pane.Title) {
			paneSet[pane.ID] = true
			windowSet[pane.WindowID] = true
		}
	}

	windows := []Window{}
	sessionSet := map[string]bool{}
	for _, window := range state.Windows {
		if windowSet[window.ID] {
			windows = append(windows, window)
			sessionSet[window.SessionID] = true
		}
	}
	for sessionID := range directSessionSet {
		sessionSet[sessionID] = true
	}

	sessions := []Session{}
	for _, session := range state.Sessions {
		if sessionSet[session.ID] {
			sessions = append(sessions, session)
		}
	}

	panes := []Pane{}
	for _, pane := range state.Panes {
		if paneSet[pane.ID] && windowSet[pane.WindowID] {
			panes = append(panes, pane)
		}
	}

	return TmuxState{Sessions: sessions, Windows: windows, Panes: panes}
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

func joinKeys(keys []string) string {
	if len(keys) == 0 {
		return ""
	}
	return strings.Join(keys, "/")
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

	ordered := []string{}
	for _, session := range sessions {
		for _, window := range windowsBySession[session.ID] {
			for _, pane := range panesByWindow[window.ID] {
				ordered = append(ordered, pane.ID)
			}
		}
	}
	return ordered
}
