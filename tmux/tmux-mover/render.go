package main

import (
	"fmt"
	"sort"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
	"github.com/mattn/go-runewidth"
)

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
	preview := renderPreview(previewText, previewErr, previewWidth, previewHeight)
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

func renderMainPanel(m model, width int, height int) string {
	switch m.mode {
	default:
		filtered := activeState(m)
		order := buildPaneOrder(filtered)
		effectiveID := effectiveSelectedPaneID(order, m.selectedPaneID, m.lastSelectedID, m.selectedIndex)
		if m.agentView {
			return renderAgentDashboard(m, filtered, effectiveID, m.scroll, width, height)
		}
		return renderPaneList(filtered, effectiveID, m.scroll, width, height, m.selectedPanes, nil, m.selfSessionID, m.selfWindowID, m.agents, m.frame)
	}
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
	visibleCount := max(1, height-2)
	scroll := max(0, selected-visibleCount+1)
	visible := sliceRows(rows, scroll, visibleCount)
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
	return renderNewSessionWithIntent(m, width, height, "New session", "Create Session", "Press enter to create or esc to cancel.")
}

func renderNewSessionWithIntent(m model, width int, height int, heading string, frameTitle string, actionHint string) string {
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
	lines = append(lines, accentStyle.Render(heading))
	lines = append(lines, plain.Render("Name: "+label))
	lines = append(lines, muted.Render("Leave blank to let tmux choose."))
	lines = append(lines, "")
	lines = append(lines, plain.Render(actionHint))

	visible := sliceRows(lines, 0, max(1, height-2))
	content := lipgloss.JoinVertical(lipgloss.Left, visible...)
	separator := mutedSeparator(rowWidth)
	return modalFrame(frameTitle, content, width, height, headerStyle, separator, lipgloss.Color("2"))
}

func renderRenameSession(m model, width int, height int) string {
	rowWidth := max(10, width-4)
	headerStyle := lipgloss.NewStyle().Bold(true).Width(rowWidth).Foreground(lipgloss.Color("2"))
	accentStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("2")).Width(rowWidth)
	muted := lipgloss.NewStyle().Foreground(lipgloss.Color("8")).Width(rowWidth)
	plain := lipgloss.NewStyle().Width(rowWidth).Foreground(lipgloss.Color("7"))

	sessionID := sessionIDForPane(m.state, m.selectedPaneID)
	currentName := sessionNameByID(m.state, sessionID)

	lines := []string{}
	lines = append(lines, accentStyle.Render("Rename session"))
	lines = append(lines, muted.Render("Current: "+currentName))
	lines = append(lines, plain.Render("New name: "+m.input))
	lines = append(lines, "")
	lines = append(lines, plain.Render("Press enter to rename or esc to cancel."))

	visible := sliceRows(lines, 0, max(1, height-2))
	content := lipgloss.JoinVertical(lipgloss.Left, visible...)
	separator := mutedSeparator(rowWidth)
	return modalFrame("Rename Session", content, width, height, headerStyle, separator, lipgloss.Color("2"))
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
	case ModeNewSessionMovePane:
		count := len(selectedPaneIDs(m))
		if count == 0 {
			count = 1
		}
		return renderNewSessionWithIntent(m, modalWidth, modalHeight,
			fmt.Sprintf("Move %d pane(s) -> new session", count),
			"New Session (Move Panes)",
			"Press enter to create and move or esc to cancel."), true
	case ModeNewSessionMoveWindow:
		count := len(selectedWindowIDsFromPanes(m))
		if count == 0 {
			count = 1
		}
		return renderNewSessionWithIntent(m, modalWidth, modalHeight,
			fmt.Sprintf("Move %d window(s) -> new session", count),
			"New Session (Move Windows)",
			"Press enter to create and move or esc to cancel."), true
	case ModeRenameSession:
		return renderRenameSession(m, modalWidth, modalHeight), true
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

func renderPaneList(state TmuxState, selectedPaneID string, scroll int, width int, height int, selectedPanes map[string]bool, selectedWindows map[string]bool, activeSessionID string, activeWindowID string, agents map[string]AgentState, frame int) string {
	if selectedWindows == nil {
		selectedWindows = map[string]bool{}
		for _, pane := range state.Panes {
			if selectedPanes != nil && selectedPanes[pane.ID] {
				selectedWindows[pane.WindowID] = true
			}
		}
	}
	tree := buildTreeRows(state, selectedPaneID, width, selectedPanes, selectedWindows, activeSessionID, activeWindowID, agents, frame)
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

func buildTreeRows(state TmuxState, selectedPaneID string, width int, selectedPanes map[string]bool, selectedWindows map[string]bool, activeSessionID string, activeWindowID string, agents map[string]AgentState, frame int) treeRows {
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
				dot, dotWidth := agentStatusDot(agents[pane.ID], frame)
				text := fmt.Sprintf("    %s %s  %s", paneMarker, pane.Command, pane.Path)
				text = truncateRow(text, max(1, rowWidth-dotWidth))
				if pane.ID == selectedPaneID {
					selectedRow = len(rows)
					rows = append(rows, dot+selectedStyle.Width(rowWidth-dotWidth).Render(text))
				} else {
					rows = append(rows, dot+normalStyle.Width(rowWidth-dotWidth).Render(text))
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

// agentStatusColor picks a status color deliberately clear of colors this
// file already assigns structural meaning to (session=4 blue, window=6 cyan,
// selected=2 green, delete-confirm=1 red) so a status dot never gets misread
// as one of those. Bright (9-15) ANSI codes are used throughout so the dots
// track the terminal's own theme instead of a fixed hex color.
func agentStatusColor(status AgentStatus) lipgloss.Color {
	switch status {
	case AgentStatusWaiting:
		return lipgloss.Color("11") // bright yellow: needs you
	case AgentStatusBusy:
		return lipgloss.Color("12") // bright blue: actively working
	default:
		return lipgloss.Color("8") // gray: idle / unknown
	}
}

// agentSpinnerFrames drives the busy-status animation, stepped once per
// 100ms state tick (see update.go's stateTickMsg handling of m.frame).
var agentSpinnerFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

// agentBackgroundFrames animates the HasBackgroundJob marker: a rotating
// circle, deliberately a different shape/motion than agentSpinnerFrames'
// braille spin so the two read as distinct at a glance — this marks "a
// background task is still running" independent of (and often alongside) a
// fully idle-looking Status.
var agentBackgroundFrames = []string{"◐", "◓", "◑", "◒"}

// agentWaitingBlinkFrames drives the waiting-status alert blink: a hard
// on/off flip between filled and hollow, not a smooth fade — a calm breathing
// effect reads as ambient/idle, but "needs your input" should read as an
// alert. ●/○ are the same characters already used elsewhere in the app
// (Idle/Unknown dots), so they're confirmed to render at a consistent width.
var agentWaitingBlinkFrames = []string{"●", "○"}

// agentStatusDot returns a small colored status marker (and its display
// width) for a pane's detected AI-CLI state, animated using frame (a
// monotonically increasing tick counter): busy panes get a spinning braille
// glyph, panes waiting on you get the agentWaitingBlinkFrames alert blink so
// they keep drawing the eye without relying on the terminal's own blink
// attribute. Panes with no detected agent (the zero AgentState) render as
// blank space so pane rows stay aligned.
func agentStatusDot(state AgentState, frame int) (string, int) {
	if state.Kind == AgentNone {
		return "  ", 2
	}
	glyph := "●"
	style := lipgloss.NewStyle().Foreground(agentStatusColor(state.Status))
	switch state.Status {
	case AgentStatusBusy:
		glyph = agentSpinnerFrames[frame%len(agentSpinnerFrames)]
	case AgentStatusWaiting:
		glyph = agentWaitingBlinkFrames[(frame/6)%len(agentWaitingBlinkFrames)]
		style = style.Bold(true)
	case AgentStatusUnknown:
		glyph = "○"
	}
	return style.Render(glyph) + " ", 2
}

func renderAgentDashboard(m model, state TmuxState, selectedPaneID string, scroll int, width int, height int) string {
	rowWidth := max(10, width-2)
	dash := buildAgentDashboardRows(m, state, selectedPaneID, rowWidth)
	visible := sliceRows(dash.rows, scroll, max(1, height-2))
	content := lipgloss.JoinVertical(lipgloss.Left, visible...)
	separator := mutedSeparator(rowWidth)
	headerStyle := lipgloss.NewStyle().Bold(true).Width(rowWidth)
	return panelBlock(width, height, lipgloss.JoinVertical(lipgloss.Left, headerStyle.Render(dash.header), separator, content))
}

// buildAgentDashboardRows is the AI-dashboard counterpart to buildTreeRows:
// same treeRows shape (rows + which one is selected) so ensureVisible's
// scroll math works identically for both views, just fed a different row
// source depending on m.agentView.
func buildAgentDashboardRows(m model, state TmuxState, selectedPaneID string, rowWidth int) treeRows {
	normalStyle := lipgloss.NewStyle().Width(rowWidth)
	selectedStyle := lipgloss.NewStyle().Width(rowWidth).Bold(true).Foreground(lipgloss.Color("2"))
	metaStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("8")).Width(rowWidth)
	mutedStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("8"))

	sectionTitle := map[AgentStatus]string{
		AgentStatusWaiting: "Needs input",
		AgentStatusBusy:    "Working",
		AgentStatusIdle:    "Idle",
		AgentStatusUnknown: "Unknown",
	}

	paneByID := map[string]Pane{}
	for _, pane := range state.Panes {
		paneByID[pane.ID] = pane
	}
	// Same order buildPaneOrder/activeOrder use for the AI dashboard, so
	// keyboard navigation lands on exactly the row rendered next/previous.
	order := agentDashboardOrder(state, m.agents)

	rows := []string{}
	selectedRow := -1
	lastStatus := AgentStatus(-1)
	sectionCount := 0
	for i, paneID := range order {
		pane := paneByID[paneID]
		agent := m.agents[paneID]

		if agent.Status != lastStatus {
			// Count how many entries belong to this section before rendering
			// its header.
			sectionCount = 0
			for _, id := range order[i:] {
				if m.agents[id].Status != agent.Status {
					break
				}
				sectionCount++
			}
			rows = append(rows, lipgloss.NewStyle().Bold(true).Foreground(agentStatusColor(agent.Status)).Width(rowWidth).
				Render(fmt.Sprintf("%s (%d)", sectionTitle[agent.Status], sectionCount)))
			lastStatus = agent.Status
		}

		dot, dotWidth := agentStatusDot(agent, m.frame)
		location := deletePaneLabelLocation(state, pane)
		label := agent.Task
		if label == "" {
			label = pane.Command
		}
		marker := " "
		if m.selectedPanes != nil && m.selectedPanes[pane.ID] {
			marker = "*"
		}
		primary := fmt.Sprintf("%s %s [%s]", marker, label, agent.Kind.Label())

		// The background-job marker is independent of the status section a
		// row sits under: a pane can render fully idle (you can type right
		// now) while a run_in_background Bash-tool task is still alive in
		// its process tree — this flags that case rather than folding it
		// into the Busy/Working status itself. Rendered as its own
		// pre-styled suffix (like dot above) rather than embedded in
		// primary, so its color survives primary's own style wrapping; the
		// rotating-circle animation is deliberately a different shape/motion
		// than agentStatusDot's braille spin so the two read as distinct at
		// a glance.
		backgroundMarker := ""
		backgroundMarkerWidth := 0
		if agent.HasBackgroundJob {
			glyph := agentBackgroundFrames[m.frame%len(agentBackgroundFrames)]
			backgroundMarker = " " + lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("14")).Render(glyph)
			backgroundMarkerWidth = 2
		}

		primaryWidth := max(1, rowWidth-dotWidth-backgroundMarkerWidth)
		primary = truncateRow(primary, primaryWidth)
		// Width is set to primary's own natural width (not the full
		// available row width) so the style adds no trailing padding —
		// otherwise backgroundMarker would land at the far right edge of
		// the row instead of right next to the text it's describing.
		line := dot
		if pane.ID == selectedPaneID {
			selectedRow = len(rows)
			line += selectedStyle.Width(lipgloss.Width(primary)).Render(primary)
		} else {
			line += normalStyle.Width(lipgloss.Width(primary)).Render(primary)
		}
		line += backgroundMarker
		rows = append(rows, line)
		rows = append(rows, metaStyle.Render("    "+truncateRow(location, max(1, rowWidth-4))))
	}

	if len(order) == 0 {
		rows = append(rows, mutedStyle.Render("No AI sessions detected."))
	}

	return treeRows{header: "AI Dashboard", rows: rows, selectedRow: selectedRow}
}

func deletePaneLabelLocation(state TmuxState, pane Pane) string {
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
	windowLabel := windowName
	if windowIndex != "" {
		windowLabel = fmt.Sprintf("%s:%s", windowIndex, windowName)
	}
	if sessionName != "" {
		return fmt.Sprintf("%s / %s — %s", sessionName, windowLabel, pane.Path)
	}
	return fmt.Sprintf("%s — %s", windowLabel, pane.Path)
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
	case ModeNewSessionMovePane:
		prompt = fmt.Sprintf("new session name for moved pane(s) (optional): %s", input)
	case ModeNewSessionMoveWindow:
		prompt = fmt.Sprintf("new session name for moved window(s) (optional): %s", input)
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
		item(joinKeys(keys.ToggleAgentView), "AI dashboard"),
		item("space", "select pane"),
		item("tab", "select+next"),
		item("shift+tab", "select+prev"),
		item("c", "clear selection"),
		item(joinKeys(keys.BreakPane), "break pane"),
		item(joinKeys(keys.CreateSession), "new session"),
		item(joinKeys(keys.RenameSession), "rename session"),
		item(joinKeys(keys.DeletePanes), "delete panes"),
		item(joinKeys(keys.MovePane), "move pane"),
		item(joinKeys(keys.MoveWindow), "move window"),
		item(joinKeys(keys.MovePaneNewSession), "pane -> new session"),
		item(joinKeys(keys.MoveWindowNewSession), "window -> new session"),
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
