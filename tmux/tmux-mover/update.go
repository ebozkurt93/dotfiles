package main

import (
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
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
		m.agents, m.probedNonAgents = reconcileAgentStates(m.agents, m.probedNonAgents, m.state.Panes, time.Now())
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
		if m.sessionView {
			updated, cmd := stepSessionSelection(m, 0)
			return updated, cmd
		}
		m = ensureVisible(m)
		if m.selectedPaneID != "" {
			return m, loadPreviewCmd(m.selectedPaneID)
		}
		return m, nil
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
		if m.mode == ModeNewSession || m.mode == ModeRenameSession || m.mode == ModeNewSessionMovePane || m.mode == ModeNewSessionMoveWindow {
			switch {
			case keyMatches(msg, m.keys.Cancel):
				m.mode = ModeList
				m.input = ""
				return m, nil
			case keyMatches(msg, m.keys.Accept):
				return acceptAction(m)
			case keyMatches(msg, m.keys.Backspace):
				if msg.Alt {
					m.input = deleteLastWord(m.input)
				} else if len(m.input) > 0 {
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
		if m.mode == ModeConfirmKillSession {
			switch {
			case keyMatches(msg, m.keys.ConfirmYes):
				return confirmKillSession(m)
			case keyMatches(msg, m.keys.ConfirmNo):
				m.mode = ModeList
				m.status = "Kill cancelled"
				return m, nil
			case keyMatches(msg, m.keys.Cancel):
				m.mode = ModeList
				m.status = "Kill cancelled"
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
			m.agentView = false
			m.sessionView = false
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
			if m.sessionView {
				return m, nil
			}
			return reorderPane(m, -1)
		case keyMatches(msg, m.keys.ReorderPaneDown):
			if m.sessionView {
				return m, nil
			}
			return reorderPane(m, 1)
		case keyMatches(msg, m.keys.ReorderWindowUp):
			if m.sessionView {
				return m, nil
			}
			return reorderWindow(m, -1)
		case keyMatches(msg, m.keys.ReorderWindowDown):
			if m.sessionView {
				return m, nil
			}
			return reorderWindow(m, 1)
		case keyMatches(msg, m.keys.TogglePaneSelect):
			if m.mode == ModeList && !m.sessionView {
				return togglePaneSelection(m)
			}
		case keyMatches(msg, m.keys.SelectNext):
			if m.mode == ModeList && !m.sessionView {
				updated, _ := togglePaneSelection(m)
				return moveDownByCount(updated.(model), 1)
			}
		case keyMatches(msg, m.keys.SelectPrev):
			if m.mode == ModeList && !m.sessionView {
				updated, _ := togglePaneSelection(m)
				return moveUpByCount(updated.(model), 1)
			}
		case keyMatches(msg, m.keys.ClearSelection):
			if m.sessionView {
				return m, nil
			}
			m.selectedPanes = map[string]bool{}
			m.status = "Cleared selections"
			return m, nil
		case keyMatches(msg, m.keys.ToggleAgentView):
			if m.mode == ModeList && !m.sessionView {
				m.agentView = !m.agentView
				m = syncSelection(m)
				m = ensureVisible(m)
				if m.agentView {
					m.status = "AI dashboard"
				} else {
					m.status = ""
				}
				if m.selectedPaneID != "" {
					return m, loadPreviewCmd(m.selectedPaneID)
				}
				return m, nil
			}
		case keyMatches(msg, m.keys.ToggleSessionView):
			if m.mode == ModeList {
				m.sessionView = !m.sessionView
				if m.sessionView {
					m.agentView = false
					if m.selectedSessionID == "" {
						m.selectedSessionID = m.selfSessionID
						m.lastSelectedSessionID = m.selfSessionID
					}
					m.status = "Sessions"
					updated, cmd := stepSessionSelection(m, 0)
					return updated, cmd
				}
				m.status = ""
				m = syncSelection(m)
				m = ensureVisible(m)
				if m.selectedPaneID != "" {
					return m, loadPreviewCmd(m.selectedPaneID)
				}
				return m, nil
			}
		case keyMatches(msg, m.keys.KillSession):
			if m.mode == ModeList && m.sessionView {
				if m.selectedSessionID == "" {
					m.status = "No session selected"
					return m, nil
				}
				m.mode = ModeConfirmKillSession
				m.status = fmt.Sprintf("Kill session %q? y/n", sessionNameByID(m.state, m.selectedSessionID))
				return m, nil
			}
		case keyMatches(msg, m.keys.MovePane):
			if m.mode == ModeList && !m.sessionView {
				m.mode = ModePickWindow
				m.targetIndex = initialWindowTargetIndex(m)
				return m, nil
			}
		case keyMatches(msg, m.keys.MoveWindow):
			if m.mode == ModeList && !m.sessionView {
				m.mode = ModePickSession
				m.targetIndex = initialSessionTargetIndex(m)
				return m, nil
			}
		case keyMatches(msg, m.keys.MovePaneNewSession):
			if m.mode == ModeList && !m.sessionView {
				m.mode = ModeNewSessionMovePane
				m.input = ""
				return m, nil
			}
		case keyMatches(msg, m.keys.MoveWindowNewSession):
			if m.mode == ModeList && !m.sessionView {
				m.mode = ModeNewSessionMoveWindow
				m.input = ""
				return m, nil
			}
		case keyMatches(msg, m.keys.CreateSession):
			if m.mode == ModeList {
				m.mode = ModeNewSession
				m.input = ""
				return m, nil
			}
		case keyMatches(msg, m.keys.RenameSession):
			if m.mode == ModeList && !m.sessionView {
				sessionID := sessionIDForPane(m.state, m.selectedPaneID)
				if sessionID == "" {
					m.status = "No session selected"
					return m, nil
				}
				m.mode = ModeRenameSession
				m.input = sessionNameByID(m.state, sessionID)
				return m, nil
			}
		case keyMatches(msg, m.keys.DeletePanes):
			if m.mode == ModeList && !m.sessionView {
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
			if m.mode == ModeList && !m.sessionView {
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
				if msg.Alt {
					m.filterInput = deleteLastWord(m.filterInput)
				} else if len(m.filterInput) > 0 {
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
	case sessionPreviewMsg:
		if !m.sessionView || msg.sessionID != m.selectedSessionID {
			return m, nil
		}
		m.preview = msg.text
		m.previewErr = msg.err
		return m, nil
	case previewMsg:
		if m.sessionView {
			return m, nil
		}
		if msg.paneID == currentPaneID(m) {
			m.preview = msg.text
			m.previewErr = msg.err
		}
		return m, nil
	case stateTickMsg:
		// stateTickCmd must only ever be re-armed here — exactly one
		// self-sustaining tick chain. Every other loadStateCmd() call site
		// (pane moves, renames, deletes, break-pane, ...) triggers a
		// one-shot stateMsg refresh; it used to also re-arm a *new*
		// permanent stateTickCmd chain of its own, which meant every action
		// silently doubled the ongoing tick rate forever (and m.frame's
		// animations sped up more with every action taken).
		m.frame++
		return m, tea.Batch(loadStateCmd(), stateTickCmd())
	case agentTickMsg:
		return m, refreshAgentsCmd(m.agents)
	case agentStatusMsg:
		now := msg.now
		procs, _ := listProcesses()
		paneByID := paneIndexByID(m.state.Panes)
		for paneID, content := range msg.results {
			state, ok := m.agents[paneID]
			if !ok {
				continue
			}
			raw := detectAgentStatus(state.Kind, content, state.Status)
			next := applyIdleDebounce(state, settleKey(state.Kind, paneByID[paneID].Title, content), raw, now)
			next.HasBackgroundJob = paneHasActiveBackgroundTask(procs, state.PID) || contentHasBackgroundAgentJob(content)
			m.agents[paneID] = next
		}
		for paneID, since := range msg.unseen {
			if state, ok := m.agents[paneID]; ok {
				state.Unseen = true
				state.UnseenSince = since
				m.agents[paneID] = state
			}
		}
		if msg.unseenFresh {
			for paneID, state := range m.agents {
				if state.Unseen && msg.unseen[paneID].IsZero() {
					state.Unseen = false
					m.agents[paneID] = state
				}
			}
		}
		return m, agentTickCmd()
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

type sessionPreviewMsg struct {
	sessionID string
	text      string
	err       error
}

type stateTickMsg struct{}

type agentTickMsg struct{}

type agentStatusMsg struct {
	results     map[string]string
	now         time.Time
	unseen      map[string]time.Time
	unseenFresh bool
}

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

// loadSessionPreviewCmd captures every target pane, then hands their actual
// (blank-trimmed) content sizes to sessionPreviewFit to decide how many
// panes fit and how many lines each gets — capture has to happen first here
// since the fit decision depends on real content, not just a count. Panes
// sessionPreviewFit drops are reported as a trailing "+N more pane(s)" note
// instead of being silently cut off by the preview panel's own height
// truncation.
func loadSessionPreviewCmd(sessionID string, targets []panePreviewTarget, previewHeight int) tea.Cmd {
	return func() tea.Msg {
		if len(targets) == 0 {
			return sessionPreviewMsg{sessionID: sessionID}
		}
		captured := make([]string, len(targets))
		natural := make([]int, len(targets))
		for i, target := range targets {
			text, err := capturePane(target.PaneID)
			if err != nil {
				text = ""
			}
			captured[i] = trimTrailingBlankLines(text)
			natural[i] = meaningfulLineCount(text)
		}
		linesPerPane, shown := sessionPreviewFit(previewHeight, natural)

		headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("6"))
		paneCountStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
		mutedStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
		var b strings.Builder
		for i := 0; i < shown; i++ {
			target := targets[i]
			if i > 0 {
				b.WriteString("\n")
			}
			label := target.Window.Name
			if target.Window.Index != "" {
				label = fmt.Sprintf("%s:%s", target.Window.Index, target.Window.Name)
			}
			header := headerStyle.Render(fmt.Sprintf("── %s ──", label))
			// Only flag which pane when there's something to flag: a window
			// with one pane already shows all of it, so noting "pane 0"
			// would just be noise on the common case.
			if target.WindowPaneCount > 1 {
				header += " " + paneCountStyle.Render(fmt.Sprintf("(pane %d)", target.PaneIndex))
			}
			b.WriteString(header)
			b.WriteString("\n")
			if captured[i] == "" {
				b.WriteString(mutedStyle.Render("(empty)"))
			} else {
				b.WriteString(lastNLines(captured[i], linesPerPane[i]))
			}
			b.WriteString("\n")
		}
		if more := len(targets) - shown; more > 0 {
			b.WriteString("\n")
			b.WriteString(mutedStyle.Render(fmt.Sprintf("… +%d more pane(s) not shown", more)))
		}
		return sessionPreviewMsg{sessionID: sessionID, text: b.String()}
	}
}

func stateTickCmd() tea.Cmd {
	return tea.Tick(100*time.Millisecond, func(time.Time) tea.Msg {
		return stateTickMsg{}
	})
}

func agentTickCmd() tea.Cmd {
	return tea.Tick(1*time.Second, func(time.Time) tea.Msg {
		return agentTickMsg{}
	})
}

func refreshAgentsCmd(agents map[string]AgentState) tea.Cmd {
	paneIDs := make([]string, 0, len(agents))
	for paneID := range agents {
		paneIDs = append(paneIDs, paneID)
	}
	return func() tea.Msg {
		results := make(map[string]string, len(paneIDs))
		for _, paneID := range paneIDs {
			text, err := capturePane(paneID)
			if err != nil {
				continue
			}
			results[paneID] = ansi.Strip(text)
		}

		// The TUI's own live tracking above has no memory of anything that
		// finished before it launched (a fresh model always starts with
		// prevStatus Unknown, and shouldNotifyAgentTransition never flags a
		// pane on its first-ever read as unseen) — so Unseen state is read
		// from the --watch-agents loop's persisted snapshot (persist.go)
		// instead of derived locally. unseenFresh distinguishes "the
		// watcher is running and says nothing is unseen" from "the watcher
		// isn't running, so this has nothing to say" — only the former
		// should be allowed to clear a previously-known Unseen flag.
		unseen := map[string]time.Time{}
		unseenFresh := false
		if persisted, ok := loadAgentsStateFile(); ok {
			unseenFresh = true
			for _, p := range persisted.Panes {
				if !p.Unseen {
					continue
				}
				since, err := time.Parse(time.RFC3339, p.UnseenSince)
				if err != nil {
					since = time.Now()
				}
				unseen[p.PaneID] = since
			}
		}

		return agentStatusMsg{results: results, now: time.Now(), unseen: unseen, unseenFresh: unseenFresh}
	}
}

// reconcileAgentStates re-derives which panes are AI-CLI panes on every fast
// (100ms) state refresh. probed tracks, per pane ID, the pane_current_command
// value it was last probed against via probeAgentKindByProcessTree and when
// — so an ambiguous runtime pane (see isAmbiguousRuntimeCommand) that hasn't
// resolved yet gets that (comparatively expensive) probe retried every
// probeRetryInterval instead of exactly once ever, and a pane already
// resolved to a real kind stays resolved even though its
// pane_current_command keeps reading e.g. "node" rather than "gemini".
//
// A pane that fails to classify on a given tick isn't dropped immediately:
// it keeps its previous AgentState (Status included) until
// agentKindGracePeriod has elapsed since Kind was last actually confirmed,
// so a single transient misread of pane_current_command can't silently
// reset the pane to Unknown and swallow whatever status transition happens
// to straddle that tick.
func reconcileAgentStates(agents map[string]AgentState, probed map[string]probeRecord, panes []Pane, now time.Time) (map[string]AgentState, map[string]probeRecord) {
	if agents == nil {
		agents = map[string]AgentState{}
	}
	next := make(map[string]AgentState, len(agents))
	nextProbed := make(map[string]probeRecord, len(probed))
	for _, pane := range panes {
		kind := detectAgentKind(pane.Command)
		if kind == AgentNone && isAmbiguousRuntimeCommand(pane.Command) {
			if existing, ok := agents[pane.ID]; ok && existing.Kind != AgentNone {
				kind = existing.Kind
				nextProbed[pane.ID] = probed[pane.ID]
			} else if rec, ok := probed[pane.ID]; !ok || rec.command != pane.Command || now.Sub(rec.lastTry) >= probeRetryInterval {
				kind = probeAgentKindByProcessTree(pane.PID)
				nextProbed[pane.ID] = probeRecord{command: pane.Command, lastTry: now}
			} else {
				nextProbed[pane.ID] = probed[pane.ID]
			}
		}
		if kind == AgentNone {
			if existing, ok := agents[pane.ID]; ok && existing.Kind != AgentNone && now.Sub(existing.KindConfirmedAt) < agentKindGracePeriod {
				next[pane.ID] = existing
			}
			continue
		}
		state, existed := agents[pane.ID]
		if !existed {
			state = AgentState{Kind: kind}
		}
		state.Kind = kind
		state.Task = parseAgentTaskLabel(pane.Title)
		state.PID = pane.PID
		state.KindConfirmedAt = now
		next[pane.ID] = state
	}
	return next, nextProbed
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
			m.targetIndex = (m.targetIndex + 1) % len(choices)
		}
		return m, nil
	case ModePickSession:
		choices := sessionChoicesForMove(m)
		if len(choices) > 0 {
			m.targetIndex = (m.targetIndex + 1) % len(choices)
		}
		return m, nil
	default:
		if m.sessionView {
			return stepSessionSelection(m, 1)
		}
		order := activeOrder(m)
		if len(order) > 0 {
			m = normalizeSelectedIndex(m)
			m.selectedIndex = (m.selectedIndex + 1) % len(order)
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
		choices := windowChoicesForMove(m)
		if len(choices) > 0 {
			m.targetIndex = (m.targetIndex - 1 + len(choices)) % len(choices)
		}
		return m, nil
	case ModePickSession:
		choices := sessionChoicesForMove(m)
		if len(choices) > 0 {
			m.targetIndex = (m.targetIndex - 1 + len(choices)) % len(choices)
		}
		return m, nil
	default:
		if m.sessionView {
			return stepSessionSelection(m, -1)
		}
		order := activeOrder(m)
		if len(order) > 0 {
			m = normalizeSelectedIndex(m)
			m.selectedIndex = (m.selectedIndex - 1 + len(order)) % len(order)
			m.selectedPaneID = currentPaneID(m)
			m.lastSelectedID = m.selectedPaneID
			m.status = ""
			m = ensureVisible(m)
			return m, loadPreviewCmd(m.selectedPaneID)
		}
		return m, nil
	}
}

// stepSessionSelection advances (direction ±1) or normalizes (direction 0)
// the sessions-only view's cursor, mirroring what the pane-oriented
// moveDown/moveUp default cases do but against sessionOrder instead of
// activeOrder, since sessions aren't panes and get their own selection
// fields (m.selectedSessionID etc.) rather than overloading the pane ones.
//
// The preview panel shows a mosaic of real capture-pane content from every
// window in the session (each capped to sessionPreviewLinesPerWindow lines)
// rather than a static summary or just one pane — the preview panel's own
// height-based truncation then naturally shows as many windows as fit.
// sessionPreviewMsg carries the session ID the capture was requested for, so
// the handler in Update only applies results still relevant to the current
// selection.
func stepSessionSelection(m model, direction int) (model, tea.Cmd) {
	order := sessionOrder(activeState(m))
	if len(order) == 0 {
		return m, nil
	}
	effectiveID := effectiveSelectedPaneID(order, m.selectedSessionID, m.lastSelectedSessionID, m.selectedSessionIndex)
	if idx, ok := findPaneIndex(order, effectiveID); ok {
		m.selectedSessionIndex = idx
	}
	m.selectedSessionIndex = (m.selectedSessionIndex + direction + len(order)) % len(order)
	m.selectedSessionID = order[m.selectedSessionIndex]
	m.lastSelectedSessionID = m.selectedSessionID
	m.status = ""
	m = ensureVisible(m)

	targets := sessionPanePreviewTargets(m.state, m.selectedSessionID)
	if len(targets) == 0 {
		m.preview = sessionPreviewText(m.state, m.selectedSessionID)
		m.previewErr = nil
		return m, nil
	}
	_, _, _, previewHeight, _, _, _, _, _ := layoutDims(m, max(1, m.width-2))
	return m, loadSessionPreviewCmd(m.selectedSessionID, targets, previewHeight)
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
		if m.sessionView {
			if m.selectedSessionID == "" {
				return m, nil
			}
			if err := switchClientToSession(m.selectedSessionID, m.selfClientID); err != nil {
				m.status = fmt.Sprintf("Error: %s", err)
				return m, nil
			}
			return m, tea.Quit
		}
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
	case ModeNewSessionMovePane:
		name := strings.TrimSpace(m.input)
		selected := selectedPaneIDs(m)
		if len(selected) == 0 && m.selectedPaneID != "" {
			selected = []string{m.selectedPaneID}
		}
		m.mode = ModeList
		m.input = ""
		if len(selected) == 0 {
			m.status = "No pane selected"
			return m, nil
		}
		sessionID, windowID, placeholderPaneID, err := applySessionCreateWithIDs(name)
		if err != nil {
			m.status = fmt.Sprintf("Error: %s", err)
			return m, nil
		}
		moved, skipped, newWindowID, _, err := movePanesToWindow(m, selected, windowID)
		if err != nil {
			m.status = fmt.Sprintf("Error: %s", err)
		} else {
			if moved > 0 {
				_ = applyPaneKill(placeholderPaneID)
			}
			m.status = fmt.Sprintf("Moved %d pane(s) to new session, skipped %d", moved, skipped)
			m.selectedPanes = map[string]bool{}
			if newWindowID != "" {
				m.selfWindowID = newWindowID
				m.selfSessionID = sessionID
			}
			_ = refocusSelf(m.selfPaneID, m.selfSessionID, m.selfWindowID, m.selfClientID)
		}
		return m, tea.Batch(loadStateCmd(), loadPreviewCmd(m.selectedPaneID))
	case ModeNewSessionMoveWindow:
		name := strings.TrimSpace(m.input)
		selected := selectedWindowIDsFromPanes(m)
		if len(selected) == 0 {
			if windowID := windowIDForPane(m.state, m.selectedPaneID); windowID != "" {
				selected = []string{windowID}
			}
		}
		m.mode = ModeList
		m.input = ""
		if len(selected) == 0 {
			m.status = "No window selected"
			return m, nil
		}
		sessionID, placeholderWindowID, _, err := applySessionCreateWithIDs(name)
		if err != nil {
			m.status = fmt.Sprintf("Error: %s", err)
			return m, nil
		}
		moved, skipped, newSessionID, err := moveWindowsToSession(m, selected, sessionID)
		if err != nil {
			m.status = fmt.Sprintf("Error: %s", err)
		} else {
			if moved > 0 {
				_ = applyWindowKill(placeholderWindowID)
			}
			m.status = fmt.Sprintf("Moved %d window(s) to new session, skipped %d", moved, skipped)
			m.selectedPanes = map[string]bool{}
			if newSessionID != "" {
				m.selfSessionID = newSessionID
			}
			_ = refocusSelf(m.selfPaneID, m.selfSessionID, m.selfWindowID, m.selfClientID)
		}
		return m, tea.Batch(loadStateCmd(), loadPreviewCmd(m.selectedPaneID))
	case ModeRenameSession:
		name := strings.TrimSpace(m.input)
		sessionID := sessionIDForPane(m.state, m.selectedPaneID)
		if name == "" || sessionID == "" {
			m.status = "Rename cancelled"
		} else if err := applySessionRename(sessionID, name); err != nil {
			m.status = fmt.Sprintf("Error: %s", err)
		} else {
			m.status = fmt.Sprintf("Renamed session to %s", name)
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

func confirmKillSession(m model) (tea.Model, tea.Cmd) {
	sessionID := m.selectedSessionID
	m.mode = ModeList
	if sessionID == "" {
		m.status = "No session selected"
		return m, nil
	}
	name := sessionNameByID(m.state, sessionID)
	if err := applySessionKill(sessionID); err != nil {
		m.status = fmt.Sprintf("Error: %s", err)
		return m, loadStateCmd()
	}
	m.status = fmt.Sprintf("Killed session %s", name)
	m.selectedSessionID = ""
	m.lastSelectedSessionID = ""
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
