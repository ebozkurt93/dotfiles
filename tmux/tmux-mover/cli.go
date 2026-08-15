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
	pane             Pane
	kind             AgentKind
	status           AgentStatus
	hasBackgroundJob bool
}

// agentSnapshotJSON is the --agents-json output shape for a single pane.
// Field names/casing are the contract for scripts consuming this —
// deliberately plain data with no display opinions (color, icons,
// formatting) baked in; callers decide all of that themselves. Only panes
// detected as an AI CLI (Claude/Gemini/Codex) are included — this is
// specifically an AI-agent status feed, not a general dump of tmux-mover's
// pane/session state.
type agentSnapshotJSON struct {
	PaneID        string `json:"pane_id"`
	Kind          string `json:"kind"`
	Status        string `json:"status"`
	Task          string `json:"task"`
	Session       string `json:"session"`
	WindowIndex   string `json:"window_index"`
	WindowName    string `json:"window_name"`
	Path          string `json:"path"`
	BackgroundJob bool   `json:"background_job"`
	// Unseen/UnseenSince are only ever populated when this snapshot came
	// from the --watch-agents loop's persisted state (see persist.go) — a
	// one-shot live read (collectAgentSnapshots, used when the watcher isn't
	// running) has no history to know a pane finished before this exact
	// invocation, so they're left at their zero values in that fallback
	// path rather than guessed at.
	Unseen      bool   `json:"unseen"`
	UnseenSince string `json:"unseen_since,omitempty"`
}

type agentStatusJSON struct {
	Counts struct {
		Waiting int `json:"waiting"`
		Busy    int `json:"busy"`
		Idle    int `json:"idle"`
		Unseen  int `json:"unseen"`
	} `json:"counts"`
	Panes []agentSnapshotJSON `json:"panes"`
}

func collectAgentSnapshots() ([]agentSnapshot, TmuxState, error) {
	state, err := loadTmuxState()
	if err != nil {
		return nil, TmuxState{}, err
	}

	procs, _ := listProcesses()
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
		hasJob := paneHasActiveBackgroundTask(procs, pane.PID) || contentHasBackgroundAgentJob(content)
		snapshots = append(snapshots, agentSnapshot{pane: pane, kind: kind, status: status, hasBackgroundJob: hasJob})
	}
	return snapshots, state, nil
}

// countByStatus buckets snapshots for the plain-text/JSON count summary.
// A pane that renders idle but still has a background task running counts
// as busy here — from the plain "N working, N idle" summary's point of
// view, it isn't done yet — while the per-pane JSON output still reports its
// real Status plus an explicit background_job field for callers that want
// the nuance.
func countByStatus(snapshots []agentSnapshot) (waiting, busy, idle int) {
	for _, s := range snapshots {
		switch {
		case s.status == AgentStatusWaiting:
			waiting++
		case s.status == AgentStatusBusy || s.hasBackgroundJob:
			busy++
		default:
			idle++
		}
	}
	return
}

// runStatusCLI implements `tmux-mover --agents-status` (a human-readable
// sentence) and `tmux-mover --agents-json` (structured data): a summary of
// AI-CLI pane status across all tmux sessions, meant to be consumed by a
// script (e.g. a tmux status-right segment) rather than the interactive TUI.
//
// It prefers the --watch-agents loop's persisted snapshot (persist.go) when
// one is fresh: that's debounced status plus Unseen bookkeeping the watcher
// derives over time, which a single point-in-time read can't reconstruct
// (a one-shot invocation has no history — it can't tell "just went idle" from
// "has been idle for an hour"). Falls back to a live one-shot read via
// collectAgentSnapshots when the watcher isn't running, same as before this
// existed; that path just can't report Unseen.
func runStatusCLI(jsonFormat bool) int {
	if persisted, ok := loadAgentsStateFile(); ok {
		return printAgentStatus(persisted, jsonFormat)
	}

	snapshots, state, err := collectAgentSnapshots()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	return printAgentStatus(buildAgentStatusJSON(snapshots, state), jsonFormat)
}

func printAgentStatus(out agentStatusJSON, jsonFormat bool) int {
	if jsonFormat {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		if err := enc.Encode(out); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		return 0
	}
	fmt.Println(formatAgentStatusPlain(out.Counts.Waiting, out.Counts.Busy, out.Counts.Idle, out.Counts.Unseen))
	return 0
}

func formatAgentStatusPlain(waiting, busy, idle, unseen int) string {
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
	if unseen > 0 {
		result += fmt.Sprintf(" (%d finished unseen)", unseen)
	}
	return result
}

func buildAgentStatusJSON(snapshots []agentSnapshot, state TmuxState) agentStatusJSON {
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
			PaneID:        snap.pane.ID,
			Kind:          snap.kind.Slug(),
			Status:        snap.status.String(),
			Task:          parseAgentTaskLabel(snap.pane.Title),
			Session:       sessionByID[snap.pane.SessionID],
			WindowIndex:   window.Index,
			WindowName:    window.Name,
			Path:          snap.pane.Path,
			BackgroundJob: snap.hasBackgroundJob,
		})

		switch {
		case snap.status == AgentStatusWaiting:
			out.Counts.Waiting++
		case snap.status == AgentStatusBusy || snap.hasBackgroundJob:
			out.Counts.Busy++
		default:
			out.Counts.Idle++
		}
	}

	return out
}
