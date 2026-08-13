package main

import (
	"fmt"
	"os"
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
			now := time.Now()
			for paneID, prev := range agents {
				content, err := capturePane(paneID)
				if err != nil {
					continue
				}
				content = ansi.Strip(content)
				raw := detectAgentStatus(prev.Kind, content, prev.Status)
				next := applyIdleDebounce(prev, content, raw, now)
				if shouldNotifyAgentTransition(prev.Status, next.Status) {
					notifySound()
					notifyBanner(agentTransitionTitle(next), agentTransitionMessage(next, paneByID[paneID], sessionByID, windowByID))
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

func agentTransitionTitle(next AgentState) string {
	if next.Status == AgentStatusWaiting {
		return next.Kind.Label() + " is waiting for input"
	}
	return next.Kind.Label() + " finished"
}

// agentTransitionMessage builds the notification body: session:window, plus
// the pane's task label (set by the CLI itself, e.g. its current TODO) when
// one is available.
func agentTransitionMessage(next AgentState, pane Pane, sessionByID map[string]string, windowByID map[string]Window) string {
	window := windowByID[pane.WindowID]
	location := fmt.Sprintf("%s:%s", sessionByID[pane.SessionID], window.Name)
	if next.Task == "" {
		return location
	}
	return location + " — " + next.Task
}

// shouldNotifyAgentTransition reports whether an agent pane's status change
// is one the user asked to be notified about: it started waiting on input,
// or it just finished working (busy -> idle). A fresh pane's first-ever read
// (prev == AgentStatusUnknown) never notifies, since that's tmux-mover
// discovering an already-running agent rather than a state change.
func shouldNotifyAgentTransition(prev, next AgentStatus) bool {
	if prev == AgentStatusUnknown {
		return false
	}
	if next == AgentStatusWaiting && prev != AgentStatusWaiting {
		return true
	}
	if prev == AgentStatusBusy && next == AgentStatusIdle {
		return true
	}
	return false
}
