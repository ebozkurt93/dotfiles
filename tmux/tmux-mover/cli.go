package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/charmbracelet/x/ansi"
)

// agentSnapshot is a one-shot (non-debounced) status read of a single AI-CLI
// pane, for the --agents-status/--agents-json CLI output. Unlike the live
// TUI, a one-off process has no prior state to debounce against, so this is
// a point-in-time read rather than the smoothed status shown while
// tmux-mover is running.
type agentSnapshot struct {
	pane   Pane
	kind   AgentKind
	status AgentStatus
}

// agentSnapshotJSON is the --agents-json output shape for a single pane.
// Field names/casing are the contract for scripts consuming this —
// deliberately plain data with no display opinions (color, icons,
// formatting) baked in; callers decide all of that themselves. Only panes
// detected as an AI CLI (Claude/Gemini/Codex) are included — this is
// specifically an AI-agent status feed, not a general dump of tmux-mover's
// pane/session state.
type agentSnapshotJSON struct {
	PaneID      string `json:"pane_id"`
	Kind        string `json:"kind"`
	Status      string `json:"status"`
	Task        string `json:"task"`
	Session     string `json:"session"`
	WindowIndex string `json:"window_index"`
	WindowName  string `json:"window_name"`
	Path        string `json:"path"`
}

type agentStatusJSON struct {
	Counts struct {
		Waiting int `json:"waiting"`
		Busy    int `json:"busy"`
		Idle    int `json:"idle"`
	} `json:"counts"`
	Panes []agentSnapshotJSON `json:"panes"`
}

func collectAgentSnapshots() ([]agentSnapshot, TmuxState, error) {
	state, err := loadTmuxState()
	if err != nil {
		return nil, TmuxState{}, err
	}

	snapshots := []agentSnapshot{}
	for _, pane := range state.Panes {
		kind := detectAgentKind(pane.Command)
		if kind == AgentNone && isAmbiguousRuntimeCommand(pane.Command) {
			kind = probeAgentKindByProcessTree(pane.PID)
		}
		if kind == AgentNone {
			continue
		}
		content, err := capturePane(pane.ID)
		if err != nil {
			continue
		}
		content = ansi.Strip(content)
		status := detectAgentStatus(kind, content, AgentStatusIdle)
		snapshots = append(snapshots, agentSnapshot{pane: pane, kind: kind, status: status})
	}
	return snapshots, state, nil
}

func countByStatus(snapshots []agentSnapshot) (waiting, busy, idle int) {
	for _, s := range snapshots {
		switch s.status {
		case AgentStatusWaiting:
			waiting++
		case AgentStatusBusy:
			busy++
		default:
			idle++
		}
	}
	return
}

// runStatusCLI implements `tmux-mover --agents-status` (a human-readable
// sentence) and `tmux-mover --agents-json` (structured data): a one-shot
// summary of AI-CLI pane status across all tmux sessions, meant to be
// consumed by a script (e.g. a tmux status-right segment) rather than the
// interactive TUI.
func runStatusCLI(jsonFormat bool) int {
	snapshots, state, err := collectAgentSnapshots()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}

	if jsonFormat {
		if err := printAgentStatusJSON(snapshots, state); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		return 0
	}

	waiting, busy, idle := countByStatus(snapshots)
	fmt.Println(formatAgentStatusPlain(waiting, busy, idle))
	return 0
}

func formatAgentStatusPlain(waiting, busy, idle int) string {
	if waiting == 0 && busy == 0 && idle == 0 {
		return "No AI sessions detected."
	}
	parts := []string{}
	if waiting > 0 {
		parts = append(parts, fmt.Sprintf("%d waiting for input", waiting))
	}
	if busy > 0 {
		parts = append(parts, fmt.Sprintf("%d working", busy))
	}
	if idle > 0 {
		parts = append(parts, fmt.Sprintf("%d idle", idle))
	}
	result := parts[0]
	for _, p := range parts[1:] {
		result += ", " + p
	}
	return result
}

func printAgentStatusJSON(snapshots []agentSnapshot, state TmuxState) error {
	sessionByID := map[string]string{}
	for _, s := range state.Sessions {
		sessionByID[s.ID] = s.Name
	}
	windowByID := map[string]Window{}
	for _, w := range state.Windows {
		windowByID[w.ID] = w
	}

	out := agentStatusJSON{Panes: []agentSnapshotJSON{}}
	for _, snap := range snapshots {
		window := windowByID[snap.pane.WindowID]
		out.Panes = append(out.Panes, agentSnapshotJSON{
			PaneID:      snap.pane.ID,
			Kind:        snap.kind.Slug(),
			Status:      snap.status.String(),
			Task:        parseAgentTaskLabel(snap.pane.Title),
			Session:     sessionByID[snap.pane.SessionID],
			WindowIndex: window.Index,
			WindowName:  window.Name,
			Path:        snap.pane.Path,
		})

		switch snap.status {
		case AgentStatusWaiting:
			out.Counts.Waiting++
		case AgentStatusBusy:
			out.Counts.Busy++
		default:
			out.Counts.Idle++
		}
	}

	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	return enc.Encode(out)
}
