package main

import (
	"strings"
	"testing"
)

func TestSelectPaneIndexByID(t *testing.T) {
	order := []string{"%1", "%2", "%3"}
	idx := selectPaneIndex(order, "%2", 0)
	if idx != 1 {
		t.Fatalf("expected index 1, got %d", idx)
	}
}

func TestSelectPaneIndexFallback(t *testing.T) {
	order := []string{"%1", "%2"}
	idx := selectPaneIndex(order, "%9", 1)
	if idx != 1 {
		t.Fatalf("expected fallback index 1, got %d", idx)
	}
}

func TestConsumeCount(t *testing.T) {
	buf := "12"
	if got := consumeCount(&buf, 1); got != 12 {
		t.Fatalf("expected 12, got %d", got)
	}
	if buf != "" {
		t.Fatalf("expected buffer cleared")
	}
}

func TestTruncatePreviewResetsANSI(t *testing.T) {
	input := "\x1b[31mred text"
	out := truncatePreview(input, 20, 1)
	if !strings.HasSuffix(out, "\x1b[0m") {
		t.Fatalf("expected ansi reset suffix")
	}
}

func TestNormalizeKeymapFallback(t *testing.T) {
	empty := Keymap{}
	got := normalizeKeymap(empty)
	if len(got.MoveDown) == 0 || len(got.MovePane) == 0 {
		t.Fatalf("expected default keymap")
	}
}

func TestNormalizeKeymapKeepsCustom(t *testing.T) {
	custom := Keymap{MoveDown: []string{"j"}}
	got := normalizeKeymap(custom)
	if len(got.MoveDown) != 1 || got.MoveDown[0] != "j" {
		t.Fatalf("expected custom keymap preserved")
	}
}
