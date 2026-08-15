package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func withTempHome(t *testing.T) {
	t.Helper()
	dir := t.TempDir()
	prev := os.Getenv("HOME")
	os.Setenv("HOME", dir)
	t.Cleanup(func() { os.Setenv("HOME", prev) })
}

func TestWriteAndLoadAgentsStateFileRoundTrip(t *testing.T) {
	withTempHome(t)

	want := agentStatusJSON{}
	want.Counts.Waiting = 1
	want.Counts.Unseen = 1
	want.Panes = []agentSnapshotJSON{
		{PaneID: "%1", Kind: "claude", Status: "waiting", Unseen: true, UnseenSince: "2026-01-01T00:00:00Z"},
	}

	if err := writeAgentsStateFile(want); err != nil {
		t.Fatalf("writeAgentsStateFile error: %v", err)
	}

	got, ok := loadAgentsStateFile()
	if !ok {
		t.Fatalf("expected loadAgentsStateFile to report fresh data")
	}
	if len(got.Panes) != 1 || got.Panes[0].PaneID != "%1" || !got.Panes[0].Unseen {
		t.Fatalf("unexpected roundtrip result: %+v", got)
	}
	if got.Counts.Unseen != 1 {
		t.Fatalf("expected unseen count 1, got %d", got.Counts.Unseen)
	}
}

func TestLoadAgentsStateFileMissing(t *testing.T) {
	withTempHome(t)

	if _, ok := loadAgentsStateFile(); ok {
		t.Fatalf("expected ok=false when no state file has been written")
	}
}

func TestLoadAgentsStateFileStale(t *testing.T) {
	withTempHome(t)

	if err := writeAgentsStateFile(agentStatusJSON{}); err != nil {
		t.Fatalf("writeAgentsStateFile error: %v", err)
	}
	old := time.Now().Add(-2 * agentsStateFreshness)
	if err := os.Chtimes(agentsStatePath(), old, old); err != nil {
		t.Fatalf("os.Chtimes error: %v", err)
	}

	if _, ok := loadAgentsStateFile(); ok {
		t.Fatalf("expected ok=false for a stale state file")
	}
}

func TestWriteAgentsStateFileIsAtomic(t *testing.T) {
	withTempHome(t)

	if err := writeAgentsStateFile(agentStatusJSON{}); err != nil {
		t.Fatalf("writeAgentsStateFile error: %v", err)
	}
	if _, err := os.Stat(filepath.Join(filepath.Dir(agentsStatePath()), "agents-state.json.tmp")); !os.IsNotExist(err) {
		t.Fatalf("expected the .tmp file to be renamed away, stat error: %v", err)
	}
}
