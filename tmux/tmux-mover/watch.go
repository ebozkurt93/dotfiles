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
				}
				agents[paneID] = next
			}
		}
	}
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
