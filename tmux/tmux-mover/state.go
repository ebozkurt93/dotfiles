package main

import (
	"fmt"
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
	var tree treeRows
	if m.agentView {
		tree = buildAgentDashboardRows(m, state, effectiveID, max(10, listWidth-2))
	} else {
		tree = buildTreeRows(state, effectiveID, listWidth, m.selectedPanes, nil, m.selfSessionID, m.selfWindowID, m.agents, m.frame)
	}
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
	state := m.state
	if m.filterActive && strings.TrimSpace(m.filterInput) != "" {
		state = filterState(state, m.filterInput)
	}
	if m.agentView {
		state = agentOnlyState(state, m.agents)
	}
	return state
}

func agentOnlyState(state TmuxState, agents map[string]AgentState) TmuxState {
	if len(agents) == 0 {
		return TmuxState{}
	}

	panes := []Pane{}
	windowSet := map[string]bool{}
	for _, pane := range state.Panes {
		if _, ok := agents[pane.ID]; ok {
			panes = append(panes, pane)
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

	sessions := []Session{}
	for _, session := range state.Sessions {
		if sessionSet[session.ID] {
			sessions = append(sessions, session)
		}
	}

	return TmuxState{Sessions: sessions, Windows: windows, Panes: panes}
}

func activeOrder(m model) []string {
	state := activeState(m)
	if m.agentView {
		return agentDashboardOrder(state, m.agents)
	}
	return buildPaneOrder(state)
}

// agentDashboardOrder returns pane IDs in exactly the order the AI dashboard
// displays them: grouped by status (waiting, busy, idle, unknown), each
// group internally in the normal session/window/pane order. Keyboard
// navigation has to walk this same order — otherwise "down" can jump to a
// row nowhere near the one below the cursor on screen.
func agentDashboardOrder(state TmuxState, agents map[string]AgentState) []string {
	base := buildPaneOrder(state)
	statusSequence := []AgentStatus{AgentStatusWaiting, AgentStatusBusy, AgentStatusIdle, AgentStatusUnknown}
	order := make([]string, 0, len(base))
	for _, status := range statusSequence {
		for _, paneID := range base {
			if agent, ok := agents[paneID]; ok && agent.Status == status {
				order = append(order, paneID)
			}
		}
	}
	return order
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
	if m.selectedSessions == nil {
		m.selectedSessions = map[string]bool{}
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

func pruneSelectedSessions(selected map[string]bool, sessions []Session) map[string]bool {
	if selected == nil {
		return map[string]bool{}
	}
	valid := map[string]bool{}
	for _, session := range sessions {
		if selected[session.ID] {
			valid[session.ID] = true
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

// sessionOrder returns session IDs in the same order the sessions-only view
// (m.sessionView) displays and navigates them in — the ID-list equivalent of
// buildPaneOrder for panes, so the existing generic effectiveSelectedPaneID/
// findPaneIndex helpers work unmodified against sessions too.
func sessionOrder(state TmuxState) []string {
	sessions := orderedSessions(state)
	ids := make([]string, len(sessions))
	for i, s := range sessions {
		ids[i] = s.ID
	}
	return ids
}

// panePreviewTarget is one pane's entry in the sessions-only view's preview
// mosaic: which window it belongs to, and (via WindowPaneCount) how many
// siblings it has, so a multi-pane window can be labeled even though each of
// its panes gets its own mosaic entry.
type panePreviewTarget struct {
	Window          Window
	PaneID          string
	PaneIndex       int
	WindowPaneCount int
}

// sessionPanePreviewTargets returns every pane in a session, in
// window-then-pane order — one mosaic entry per pane (not per window), so
// the preview can actually show every pane it has room for instead of only
// each window's active one.
func sessionPanePreviewTargets(state TmuxState, sessionID string) []panePreviewTarget {
	windows := []Window{}
	for _, w := range state.Windows {
		if w.SessionID == sessionID {
			windows = append(windows, w)
		}
	}
	sort.SliceStable(windows, func(i, j int) bool {
		return windows[i].IndexNum < windows[j].IndexNum
	})

	panesByWindow := map[string][]Pane{}
	for _, p := range state.Panes {
		panesByWindow[p.WindowID] = append(panesByWindow[p.WindowID], p)
	}
	for windowID, panes := range panesByWindow {
		sort.SliceStable(panes, func(i, j int) bool {
			return panes[i].IndexNum < panes[j].IndexNum
		})
		panesByWindow[windowID] = panes
	}

	targets := []panePreviewTarget{}
	for _, w := range windows {
		panes := panesByWindow[w.ID]
		for _, p := range panes {
			targets = append(targets, panePreviewTarget{
				Window:          w,
				PaneID:          p.ID,
				PaneIndex:       p.IndexNum,
				WindowPaneCount: len(panes),
			})
		}
	}
	return targets
}

// minSessionPreviewLines is the floor sessionPreviewFit will clip a pane
// down to before giving up and dropping it entirely — below this a snippet
// stops being useful context. There is deliberately no matching upper cap:
// a pane can grow to use as much of the preview panel as is actually left
// over once every shown pane has at least this much. sessionPreviewOverhead
// is the header line + blank separator every mosaic entry costs regardless
// of its content.
const (
	minSessionPreviewLines = 4
	sessionPreviewOverhead = 2
)

// meaningfulLineCount trims trailing blank rows (a pane shorter than the
// terminal is padded with them) and returns how many lines of actual
// content remain — uncapped, so a busy pane's real size is known and
// sessionPreviewFit can decide how much of it actually fits.
func meaningfulLineCount(text string) int {
	trimmed := trimTrailingBlankLines(text)
	if trimmed == "" {
		return 0
	}
	return len(strings.Split(trimmed, "\n"))
}

// sessionPreviewFit decides, given each pane's true (uncapped) content line
// count, how many lines to actually show per pane and how many panes fit in
// the preview panel at all.
//
//  1. Every shown pane starts at min(natural, minSessionPreviewLines) — a
//     pane with only a couple of real lines (an idle prompt) only costs
//     those couple of lines, not a reserved minimum it doesn't need.
//  2. Panes that are dropped from the tail (existing window/pane order)
//     first, in as few drops as it takes for the rest to afford that floor
//     — the caller reports the drop count as "+N more" instead of cramming
//     every pane down to a sliver that stops being useful.
//  3. Whatever budget is left over after every shown pane has its floor is
//     then water-filled one line at a time to panes that still have more
//     natural content to show, round-robin, so a session with only one or
//     two panes lets them grow to fill the whole panel instead of being
//     stuck at the floor while the rest of the panel sits empty.
func sessionPreviewFit(previewHeight int, natural []int) (linesPerPane []int, shown int) {
	if len(natural) == 0 {
		return nil, 0
	}
	budget := max(1, previewHeight-2)
	cost := func(lines int) int { return lines + sessionPreviewOverhead }

	floor := func(n int) int { return min(n, minSessionPreviewLines) }

	// If not every pane fits at its floor, some will get dropped and the
	// caller appends a "+N more" note below the mosaic — reserve that
	// note's own line cost up front. Without this, water-filling below
	// happily spends the entire budget on shown panes' content, and the
	// note text is still appended to the string but then silently sliced
	// off by the preview panel's own height truncation.
	allFloorCost := 0
	for _, n := range natural {
		allFloorCost += cost(floor(n))
	}
	if allFloorCost > budget {
		budget = max(1, budget-sessionPreviewOverhead)
	}

	shown = len(natural)
	for shown > 0 {
		total := 0
		for i := 0; i < shown; i++ {
			total += cost(floor(natural[i]))
		}
		if total <= budget {
			break
		}
		shown--
	}
	if shown == 0 {
		shown = 1
	}

	lines := make([]int, shown)
	used := 0
	for i := 0; i < shown; i++ {
		lines[i] = floor(natural[i])
		used += cost(lines[i])
	}

	leftover := budget - used
	for leftover > 0 {
		progressed := false
		for i := 0; i < shown && leftover > 0; i++ {
			if lines[i] < natural[i] {
				lines[i]++
				leftover--
				progressed = true
			}
		}
		if !progressed {
			break
		}
	}
	return lines, shown
}

// sessionPreviewText renders a synthesized preview (window/pane counts) for
// the sessions-only view, used as a fallback when sessionPanePreviewTargets
// finds no live pane to capture (e.g. a session with no windows).
func sessionPreviewText(state TmuxState, sessionID string) string {
	name := ""
	for _, s := range state.Sessions {
		if s.ID == sessionID {
			name = s.Name
			break
		}
	}
	if name == "" {
		return ""
	}
	windows := []Window{}
	for _, w := range state.Windows {
		if w.SessionID == sessionID {
			windows = append(windows, w)
		}
	}
	sort.SliceStable(windows, func(i, j int) bool {
		return windows[i].IndexNum < windows[j].IndexNum
	})
	paneCountByWindow := map[string]int{}
	for _, p := range state.Panes {
		paneCountByWindow[p.WindowID]++
	}
	lines := []string{fmt.Sprintf("Session: %s", name)}
	for _, w := range windows {
		lines = append(lines, fmt.Sprintf("  %s:%s — %d pane(s)", w.Index, w.Name, paneCountByWindow[w.ID]))
	}
	return strings.Join(lines, "\n")
}

func sessionChoicesForMove(m model) []choice {
	windowID := windowIDForPane(m.state, m.selectedPaneID)
	exclude := sessionIDForWindow(m.state, windowID)
	if len(selectedWindowIDsFromPanes(m)) > 1 {
		exclude = ""
	}
	return buildSessionChoices(m.state, exclude)
}

// initialWindowTargetIndex returns the choice index of the window just before
// the current pane's window in the windows list (wrapping).
func initialWindowTargetIndex(m model) int {
	choices := windowChoicesForMove(m)
	if len(choices) == 0 {
		return 0
	}
	currentWindowID := windowIDForPane(m.state, m.selectedPaneID)
	windows := m.state.Windows
	choiceIdx := map[string]int{}
	for i, c := range choices {
		choiceIdx[c.ID] = i
	}
	currentPos := -1
	for i, w := range windows {
		if w.ID == currentWindowID {
			currentPos = i
			break
		}
	}
	if currentPos < 0 {
		return 0
	}
	for step := 1; step <= len(windows); step++ {
		idx := (currentPos - step + len(windows)) % len(windows)
		if ci, ok := choiceIdx[windows[idx].ID]; ok {
			return ci
		}
	}
	return 0
}

// initialSessionTargetIndex returns the choice index of the session just before
// the current pane's session in the sessions list (wrapping).
func initialSessionTargetIndex(m model) int {
	choices := sessionChoicesForMove(m)
	if len(choices) == 0 {
		return 0
	}
	windowID := windowIDForPane(m.state, m.selectedPaneID)
	currentSessionID := sessionIDForWindow(m.state, windowID)
	sessions := m.state.Sessions
	choiceIdx := map[string]int{}
	for i, c := range choices {
		choiceIdx[c.ID] = i
	}
	currentPos := -1
	for i, s := range sessions {
		if s.ID == currentSessionID {
			currentPos = i
			break
		}
	}
	if currentPos < 0 {
		return 0
	}
	for step := 1; step <= len(sessions); step++ {
		idx := (currentPos - step + len(sessions)) % len(sessions)
		if ci, ok := choiceIdx[sessions[idx].ID]; ok {
			return ci
		}
	}
	return 0
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
