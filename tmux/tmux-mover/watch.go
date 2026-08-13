package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"
	"time"

	"github.com/charmbracelet/x/ansi"
)

// watchInterval is how often runWatchAgents polls tmux for agent panes and
// re-captures their content. Matches the TUI's agentTickCmd cadence
// (update.go) so notifications fire at the same responsiveness whether
// tmux-mover is open or running headless via --watch-agents.
const watchInterval = 1 * time.Second

// watchPIDPath returns a fixed, OS-agnostic location for the watcher's
// pidfile — `make watch-stop`/`watch-restart` read this same path to find
// and signal a running watcher, so it deliberately isn't os.UserCacheDir()
// (which differs between darwin and linux).
func watchPIDPath() string {
	return filepath.Join(os.Getenv("HOME"), ".cache", "tmux-mover", "watch.pid")
}

func writeWatchPID() error {
	path := watchPIDPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(strconv.Itoa(os.Getpid())), 0o644)
}

func removeWatchPID() {
	_ = os.Remove(watchPIDPath())
}

// runWatchAgents implements `tmux-mover --watch-agents`: a headless,
// long-running loop that polls tmux for AI-CLI panes and plays a sound
// whenever one starts waiting for input, or finishes working (busy->idle).
// It reuses the same detection/debounce logic as the interactive TUI
// (reconcileAgentStates, detectAgentStatus, applyIdleDebounce) so a pane is
// classified identically whether or not tmux-mover's UI is open.
func runWatchAgents() int {
	if err := writeWatchPID(); err != nil {
		fmt.Fprintln(os.Stderr, "tmux-mover --watch-agents: writing pidfile:", err)
		return 1
	}
	defer removeWatchPID()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	agents := map[string]AgentState{}
	probedNonAgents := map[string]string{}

	ticker := time.NewTicker(watchInterval)
	defer ticker.Stop()

	for {
		select {
		case <-sigCh:
			return 0
		case <-ticker.C:
			state, err := loadTmuxState()
			if err != nil {
				continue
			}
			agents, probedNonAgents = reconcileAgentStates(agents, probedNonAgents, state.Panes)
			paneByID := paneIndexByID(state.Panes)
			sessionByID, windowByID := sessionAndWindowIndex(state)
			procs, _ := listProcesses()
			now := time.Now()
			for paneID, prev := range agents {
				content, err := capturePane(paneID)
				if err != nil {
					continue
				}
				content = ansi.Strip(content)
				raw := detectAgentStatus(prev.Kind, content, prev.Status)
				next := applyIdleDebounce(prev, content, raw, now)
				next.HasBackgroundJob = paneHasActiveBackgroundTask(procs, prev.PID)
				if shouldNotifyAgentTransition(prev, next) {
					notifySound()
					pane := paneByID[paneID]
					title, subtitle, body := agentTransitionNotification(next, pane, sessionByID, windowByID)
					notifyBanner(title, subtitle, body, tmuxJumpCommand(pane))
				}
				agents[paneID] = next
			}
		}
	}
}

func paneIndexByID(panes []Pane) map[string]Pane {
	byID := make(map[string]Pane, len(panes))
	for _, p := range panes {
		byID[p.ID] = p
	}
	return byID
}

func sessionAndWindowIndex(state TmuxState) (map[string]string, map[string]Window) {
	sessionByID := make(map[string]string, len(state.Sessions))
	for _, s := range state.Sessions {
		sessionByID[s.ID] = s.Name
	}
	windowByID := make(map[string]Window, len(state.Windows))
	for _, w := range state.Windows {
		windowByID[w.ID] = w
	}
	return sessionByID, windowByID
}

// agentTransitionNotification builds the (title, subtitle, body) shown for a
// pane's status change: title leads with a glyph distinguishing "needs you"
// from "done" so it's scannable at a glance; subtitle is the pane's
// session/window location, so multiple panes of the same CLI stay
// distinguishable; body is the pane's task label (set by the CLI itself,
// e.g. its current TODO) or, failing that, the pane's working directory.
func agentTransitionNotification(next AgentState, pane Pane, sessionByID map[string]string, windowByID map[string]Window) (title, subtitle, body string) {
	glyph, verb := "✅", "finished"
	if next.Status == AgentStatusWaiting {
		glyph, verb = "⏳", "waiting for input"
	}
	title = fmt.Sprintf("%s %s %s", glyph, next.Kind.Label(), verb)

	window := windowByID[pane.WindowID]
	subtitle = fmt.Sprintf("%s · %s", sessionByID[pane.SessionID], window.Name)

	body = next.Task
	if body == "" {
		body = filepath.Base(pane.Path)
	}
	return title, subtitle, body
}

// tmuxJumpCommand builds the shell command run (via terminal-notifier
// -execute, itself invoked through /bin/sh -c) when an agent-transition
// banner is clicked: select the target window/pane, then switch every
// attached tmux client over to that session (select-window/select-pane are
// session-scoped and already visible to every client; switch-client is
// per-client, so each one needs its own call).
//
// The tmux binary is resolved to an absolute path (via exec.LookPath, using
// the watcher's own environment) rather than left as a bare "tmux" — macOS
// Notification Center runs -execute with a bare $PATH that doesn't include a
// nix profile, so a bare "tmux" silently resolves to nothing and the click
// does nothing.
//
// pane.SessionID/WindowID/ID are tmux's own internal IDs ("$3"/"@12"/"%165")
// — generated by tmux itself, never derived from pane content — so
// single-quoting them is just to stop the shell from expanding "$3" as a
// positional parameter, not an injection concern.
func tmuxJumpCommand(pane Pane) string {
	tmuxBin := "tmux"
	if resolved, err := exec.LookPath("tmux"); err == nil {
		tmuxBin = resolved
	}
	return fmt.Sprintf(
		`%[1]s select-window -t '%[2]s'; %[1]s select-pane -t '%[3]s'; for c in $(%[1]s list-clients -F '#{client_name}'); do %[1]s switch-client -c "$c" -t '%[4]s'; done`,
		tmuxBin, pane.WindowID, pane.ID, pane.SessionID,
	)
}

// shouldNotifyAgentTransition reports whether an agent pane's state change is
// one the user asked to be notified about: it started waiting on input, or
// it just finished working. A fresh pane's first-ever read
// (prev.Status == AgentStatusUnknown) never notifies, since that's
// tmux-mover discovering an already-running agent rather than a state
// change.
//
// "Finished" is defined across both Status and HasBackgroundJob, not Status
// alone: the pane was doing something (actively rendering busy, or idle with
// a background task still alive) and is now fully done (idle and no
// background task) — so a render that goes idle while a run_in_background
// Bash-tool task is still running does NOT yet count as finished; the
// notification waits for the task to actually complete.
func shouldNotifyAgentTransition(prev, next AgentState) bool {
	if prev.Status == AgentStatusUnknown {
		return false
	}
	if next.Status == AgentStatusWaiting && prev.Status != AgentStatusWaiting {
		return true
	}
	wasWorking := prev.Status == AgentStatusBusy || prev.HasBackgroundJob
	isDone := next.Status == AgentStatusIdle && !next.HasBackgroundJob
	return wasWorking && isDone
}
