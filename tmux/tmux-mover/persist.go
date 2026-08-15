package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

// agentsStatePath is where the long-running --watch-agents process persists
// its live agent-status snapshot (agentStatusJSON, the same shape
// --agents-json returns) after every tick — so a one-shot CLI invocation, or
// tmux-mover's own TUI, can pick up debounced status and the Unseen
// bookkeeping (agents.go) the watcher derives over time, and so "finished
// while nobody was looking" survives across TUI open/close and CLI
// invocations rather than living only in the watcher's own memory.
func agentsStatePath() string {
	return filepath.Join(os.Getenv("HOME"), ".cache", "tmux-mover", "agents-state.json")
}

// agentsStateFreshness is how old a persisted snapshot can be before it's
// treated as stale — the watcher isn't running, or has stalled — and
// callers should fall back to a live one-shot read instead of trusting the
// file. A few missed ticks' worth of slack over watchInterval.
const agentsStateFreshness = 5 * time.Second

// writeAgentsStateFile atomically persists snap so concurrent readers (a CLI
// invocation, or the TUI) never observe a half-written file: it writes to a
// temp file in the same directory, then renames it into place, which is
// atomic on both Linux and macOS as long as source and destination share a
// filesystem (true here — same directory).
func writeAgentsStateFile(snap agentStatusJSON) error {
	path := agentsStatePath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.Marshal(snap)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// loadAgentsStateFile reads the watcher's persisted snapshot, returning
// ok=false if it doesn't exist or is older than agentsStateFreshness — the
// signal for callers to fall back to a live one-shot read instead of
// trusting (possibly long-stale) Unseen/status data.
func loadAgentsStateFile() (agentStatusJSON, bool) {
	path := agentsStatePath()
	info, err := os.Stat(path)
	if err != nil || time.Since(info.ModTime()) > agentsStateFreshness {
		return agentStatusJSON{}, false
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return agentStatusJSON{}, false
	}
	var out agentStatusJSON
	if err := json.Unmarshal(data, &out); err != nil {
		return agentStatusJSON{}, false
	}
	return out, true
}
