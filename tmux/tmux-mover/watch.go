package main

import (
	"fmt"
	"log"
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

// watchHeartbeatEvery is how often (in ticks) runWatchAgents logs a summary
// line even when nothing notable happened, so the log can answer "was the
// watcher even alive and polling at time X" — the question that used to be
// unanswerable, since watch.log stayed empty for the watcher's entire
// lifetime unless something failed outright.
const watchHeartbeatEvery = 60

// watchLogger is the destination for every diagnostic line runWatchAgents
// emits: per-tick errors, status transitions, notification attempts and
// their outcomes, and periodic heartbeats. It writes to stderr, which
// `make watch-start`/`watch-restart` already redirect to
// ~/.cache/tmux-mover/watch.log — so this is the one place to look after a
// notification that should have fired didn't.
var watchLogger = log.New(os.Stderr, "", log.LstdFlags)

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
	probedNonAgents := map[string]probeRecord{}

	ticker := time.NewTicker(watchInterval)
	defer ticker.Stop()

	watchLogger.Printf("watch-agents: started (pid %d, poll interval %s)", os.Getpid(), watchInterval)

	tickCount := 0
	for {
		select {
		case <-sigCh:
			watchLogger.Printf("watch-agents: received signal, exiting")
			return 0
		case <-ticker.C:
			tickCount++
			agents, probedNonAgents = watchTick(agents, probedNonAgents, tickCount)
		}
	}
}

// watchTick runs one poll/notify cycle and returns the updated agent and
// probe-cache state. It recovers from any panic so a single bad pane or an
// unexpected tmux/ps output shape can't silently kill the whole long-running
// watcher — the panic is logged (with a stack-free summary; see
// recover()'s value) instead, and the loop just tries again next tick.
func watchTick(agents map[string]AgentState, probedNonAgents map[string]probeRecord, tickCount int) (map[string]AgentState, map[string]probeRecord) {
	defer func() {
		if r := recover(); r != nil {
			watchLogger.Printf("watch-agents: recovered from panic in tick %d: %v", tickCount, r)
		}
	}()

	state, err := loadTmuxState()
	if err != nil {
		watchLogger.Printf("watch-agents: tick %d: loadTmuxState failed, skipping tick: %v", tickCount, err)
		return agents, probedNonAgents
	}

	prevPaneCount := len(agents)
	agents, probedNonAgents = reconcileAgentStates(agents, probedNonAgents, state.Panes, time.Now())
	if len(agents) != prevPaneCount {
		watchLogger.Printf("watch-agents: tick %d: tracking %d agent pane(s) (was %d)", tickCount, len(agents), prevPaneCount)
	}

	paneByID := paneIndexByID(state.Panes)
	sessionByID, windowByID := sessionAndWindowIndex(state)
	procs, err := listProcesses()
	if err != nil {
		watchLogger.Printf("watch-agents: tick %d: listProcesses failed (background-job detection degraded this tick): %v", tickCount, err)
	}
	// viewed is which pane each attached tmux client is actually looking at
	// right now — checked once per tick (not per pane) since it doesn't
	// depend on the pane being examined. A nil map here (on error) just
	// means nothing gets marked seen this tick rather than a crash; map
	// reads on a nil map are a defined, safe zero-value lookup in Go.
	viewed, err := currentlyViewedPaneIDs()
	if err != nil {
		watchLogger.Printf("watch-agents: tick %d: currentlyViewedPaneIDs failed (unseen-clearing degraded this tick): %v", tickCount, err)
	}
	now := time.Now()

	waiting, busy, idle := 0, 0, 0
	for paneID, prev := range agents {
		content, err := capturePane(paneID)
		if err != nil {
			watchLogger.Printf("watch-agents: tick %d: capturePane(%s) failed, keeping prior state: %v", tickCount, paneID, err)
			continue
		}
		content = ansi.Strip(content)
		pane := paneByID[paneID]
		raw := detectAgentStatus(prev.Kind, content, prev.Status)
		next := applyIdleDebounce(prev, settleKey(prev.Kind, pane.Title, content), raw, now)
		next.HasBackgroundJob = paneHasActiveBackgroundTask(procs, prev.PID) || contentHasBackgroundAgentJob(content)

		if next.Status != prev.Status || next.HasBackgroundJob != prev.HasBackgroundJob {
			watchLogger.Printf("watch-agents: tick %d: pane %s (%s) status %s->%s bgJob %v->%v",
				tickCount, paneID, prev.Kind.Label(), prev.Status, next.Status, prev.HasBackgroundJob, next.HasBackgroundJob)
		}

		if shouldNotifyAgentTransition(prev, next) {
			next.Unseen = true
			next.UnseenSince = now
			title, subtitle, body := agentTransitionNotification(next, pane, sessionByID, windowByID)
			watchLogger.Printf("watch-agents: tick %d: NOTIFY pane %s: %q / %q / %q", tickCount, paneID, title, subtitle, body)
			cfg, cfgErr := loadNotificationConfigFunc()
			if cfgErr != nil {
				watchLogger.Printf("watch-agents: tick %d: notification config failed, using %s: %v", tickCount, cfg.Mode, cfgErr)
			}
			if cfg.Sound {
				if soundTool, soundErr := notifySoundFunc(); soundErr != nil {
					watchLogger.Printf("watch-agents: tick %d: notifySound (%s) failed for pane %s: %v", tickCount, soundTool, paneID, soundErr)
				}
			}
			if cfg.Banner {
				if bannerTool, bannerErr := notifyBannerFunc(title, subtitle, body, tmuxJumpCommand(pane)); bannerErr != nil {
					watchLogger.Printf("watch-agents: tick %d: notifyBanner (%s) failed for pane %s: %v", tickCount, bannerTool, paneID, bannerErr)
				}
			}
		}

		// Cleared purely from tmux's own idea of what's on screen right
		// now — no dependency on tmux-mover's TUI having been opened, so
		// switching to the pane directly in tmux is enough on its own.
		if next.Unseen && viewed[paneID] {
			next.Unseen = false
			watchLogger.Printf("watch-agents: tick %d: pane %s marked seen (viewed directly in tmux)", tickCount, paneID)
		}

		switch {
		case next.Status == AgentStatusWaiting:
			waiting++
		case next.Status == AgentStatusBusy || next.HasBackgroundJob:
			busy++
		default:
			idle++
		}
		agents[paneID] = next
	}

	if err := writeAgentsStateFile(buildPersistedAgentStatus(agents, paneByID, sessionByID, windowByID)); err != nil {
		watchLogger.Printf("watch-agents: tick %d: writeAgentsStateFile failed: %v", tickCount, err)
	}

	if tickCount%watchHeartbeatEvery == 0 {
		watchLogger.Printf("watch-agents: heartbeat: tick %d, %d agent pane(s) tracked (%d waiting, %d busy, %d idle)",
			tickCount, len(agents), waiting, busy, idle)
	}

	return agents, probedNonAgents
}

// buildPersistedAgentStatus turns the watcher's live agents map into the
// same agentStatusJSON shape --agents-json returns (cli.go), including
// Unseen/UnseenSince — written to disk every tick (persist.go) so a
// one-shot CLI invocation or the TUI can read debounced status and Unseen
// bookkeeping without reaching into the watcher's own in-memory state.
func buildPersistedAgentStatus(agents map[string]AgentState, paneByID map[string]Pane, sessionByID map[string]string, windowByID map[string]Window) agentStatusJSON {
	out := agentStatusJSON{Panes: make([]agentSnapshotJSON, 0, len(agents))}
	for paneID, state := range agents {
		pane := paneByID[paneID]
		window := windowByID[pane.WindowID]
		unseenSince := ""
		if state.Unseen {
			unseenSince = state.UnseenSince.Format(time.RFC3339)
		}
		out.Panes = append(out.Panes, agentSnapshotJSON{
			PaneID:        paneID,
			Kind:          state.Kind.Slug(),
			Status:        state.Status.String(),
			Task:          state.Task,
			Session:       sessionByID[pane.SessionID],
			WindowIndex:   window.Index,
			WindowName:    window.Name,
			Path:          pane.Path,
			BackgroundJob: state.HasBackgroundJob,
			Unseen:        state.Unseen,
			UnseenSince:   unseenSince,
		})

		switch {
		case state.Status == AgentStatusWaiting:
			out.Counts.Waiting++
		case state.Status == AgentStatusBusy || state.HasBackgroundJob:
			out.Counts.Busy++
		default:
			out.Counts.Idle++
		}
		if state.Unseen {
			out.Counts.Unseen++
		}
	}
	return out
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
// pane's status change: title leads with a glyph distinguishing "needs you",
// "done", and "free to type, but a background task is still going" so it's
// scannable at a glance; subtitle is the pane's session/window location, so
// multiple panes of the same CLI stay distinguishable; body is the pane's
// task label (set by the CLI itself, e.g. its current TODO) or, failing
// that, the pane's working directory.
//
// This is only ever called when shouldNotifyAgentTransition has already
// returned true, so next.Status/HasBackgroundJob are exhaustively one of:
// Waiting; Idle with HasBackgroundJob (just went idle, task still running);
// or Idle without HasBackgroundJob (genuinely finished).
func agentTransitionNotification(next AgentState, pane Pane, sessionByID map[string]string, windowByID map[string]Window) (title, subtitle, body string) {
	glyph, verb := "✅", "finished"
	switch {
	case next.Status == AgentStatusWaiting:
		glyph, verb = "⏳", "waiting for input"
	case next.Status == AgentStatusIdle && next.HasBackgroundJob:
		glyph, verb = "🔄", "idle — background task still running"
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
// banner is clicked: switch every attached tmux client over to the target
// session, then select the target window/pane. switch-client is per-client,
// while select-window/select-pane update tmux's active window/pane state for
// the target session/window.
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
		`for c in $(%[1]s list-clients -F '#{client_name}'); do %[1]s switch-client -c "$c" -t '%[4]s'; done; %[1]s select-window -t '%[2]s'; %[1]s select-pane -t '%[3]s'`,
		tmuxBin, pane.WindowID, pane.ID, pane.SessionID,
	)
}

// shouldNotifyAgentTransition reports whether an agent pane's state change is
// one the user asked to be notified about: it started waiting on input, it
// just went idle while a background task is still running (so you're free to
// type, but something's still in flight), or it's now fully done. A fresh
// pane's first-ever read (prev.Status == AgentStatusUnknown) never notifies,
// since that's tmux-mover discovering an already-running agent rather than a
// state change.
//
// "Finished" is defined across both Status and HasBackgroundJob, not Status
// alone: the pane was doing something (actively rendering busy, or idle with
// a background task still alive) and is now fully done (idle and no
// background task) — so a render that goes idle while a run_in_background
// Bash-tool task is still running does NOT yet count as finished on its own;
// that transition gets its own "idle, background task still running"
// notification instead, and "finished" only fires once the task later
// actually completes (whether or not Status ever left Idle in between).
func shouldNotifyAgentTransition(prev, next AgentState) bool {
	if prev.Status == AgentStatusUnknown {
		return false
	}
	if next.Status == AgentStatusWaiting && prev.Status != AgentStatusWaiting {
		return true
	}

	prevIdleWithJob := prev.Status == AgentStatusIdle && prev.HasBackgroundJob
	nextIdleWithJob := next.Status == AgentStatusIdle && next.HasBackgroundJob
	if nextIdleWithJob && !prevIdleWithJob {
		return true
	}

	wasWorking := prev.Status == AgentStatusBusy || prev.HasBackgroundJob
	isDone := next.Status == AgentStatusIdle && !next.HasBackgroundJob
	return wasWorking && isDone
}
