package main

import (
	"strings"
	"testing"
	"time"
)

func TestDetectAgentKind(t *testing.T) {
	cases := []struct {
		command string
		want    AgentKind
	}{
		{"claude", AgentClaude},
		{".claude-wrapped", AgentClaude},
		{"gemini", AgentGemini},
		{"codex", AgentCodex},
		{"CODEX", AgentCodex},
		{"nvim", AgentNone},
		{"zsh", AgentNone},
		{"", AgentNone},
	}
	for _, c := range cases {
		if got := detectAgentKind(c.command); got != c.want {
			t.Errorf("detectAgentKind(%q) = %v, want %v", c.command, got, c.want)
		}
	}
}

func TestIsAmbiguousRuntimeCommand(t *testing.T) {
	cases := []struct {
		command string
		want    bool
	}{
		{"node", true},
		{"NODE", true},
		{"bun", true},
		{"python3", true},
		{"claude", false},
		{"nvim", false},
	}
	for _, c := range cases {
		if got := isAmbiguousRuntimeCommand(c.command); got != c.want {
			t.Errorf("isAmbiguousRuntimeCommand(%q) = %v, want %v", c.command, got, c.want)
		}
	}
}

func TestMatchAgentKindInCommandLines(t *testing.T) {
	cases := []struct {
		name  string
		lines []string
		want  AgentKind
	}{
		{
			name:  "gemini under node",
			lines: []string{"/nix/store/.../bin/node --no-warnings /nix/store/.../gemini-cli/gemini.js"},
			want:  AgentGemini,
		},
		{
			name:  "unrelated node app",
			lines: []string{"node server.js"},
			want:  AgentNone,
		},
		{
			name:  "no children",
			lines: []string{},
			want:  AgentNone,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := matchAgentKindInCommandLines(c.lines); got != c.want {
				t.Errorf("matchAgentKindInCommandLines(%v) = %v, want %v", c.lines, got, c.want)
			}
		})
	}
}

func TestDetectClaudeStatus(t *testing.T) {
	cases := []struct {
		name    string
		content string
		want    AgentStatus
	}{
		{
			name:    "busy spinner",
			content: "✳ Simplifying…\n\nesc to interrupt",
			want:    AgentStatusBusy,
		},
		{
			name:    "busy token stats",
			content: "(9m 21s · ↓ 13.7k tokens)",
			want:    AgentStatusBusy,
		},
		{
			name:    "waiting do you want",
			content: "Do you want to make this edit?\n1. Yes\n2. No",
			want:    AgentStatusWaiting,
		},
		{
			name:    "waiting deny menu",
			content: "Claude in Chrome wants to navigate\n1. Allow\n2. Deny (esc)",
			want:    AgentStatusWaiting,
		},
		{
			name:    "waiting esc to cancel",
			content: "Searching...\nesc to cancel",
			want:    AgentStatusWaiting,
		},
		{
			name:    "idle plain prompt",
			content: "╭──────╮\n│ >    │\n╰──────╯",
			want:    AgentStatusIdle,
		},
		{
			name:    "search overlay is idle, not waiting",
			content: "⌕ Search…\nsome_file.go\nanother_file.go\nesc to cancel",
			want:    AgentStatusIdle,
		},
		{
			name:    "search overlay indented is still idle",
			content: "  ⌕ Search…\nsome_file.go\nesc to cancel",
			want:    AgentStatusIdle,
		},
		{
			name:    "search phrase mid-sentence is not a search overlay",
			content: "Claude's file-search overlay (\"⌕ Search…\" with \"esc to cancel\") gets misclassified",
			want:    AgentStatusWaiting,
		},
		{
			// Regression: a real captured pane where Claude asked an ordinary
			// clarifying question ("What would you like me to test?"),
			// followed by blank padding and the next empty "❯" prompt further
			// down — not a confirmation menu, so this must stay idle.
			name: "ordinary clarifying question is not a confirmation menu",
			content: "❯ testing, think 100 seconds\n" +
				"\n" +
				"⏺ What would you like me to test? There's no specific task in your message yet — let me know what you'd\n" +
				"  like me to look at or work on.\n" +
				"\n" +
				"✻ Brewed for 5s\n" +
				"\n" +
				"❯ test\n" +
				"\n" +
				"⏺ I need a concrete task to act on — what would you like me to do?\n" +
				"\n" +
				"✻ Baked for 3s\n" +
				strings.Repeat("\n", 20) +
				"───────────────────────\n" +
				"❯ \n" +
				"───────────────────────\n" +
				"  ⏸ manual mode on · ? for shortcuts · ← for agents",
			want: AgentStatusIdle,
		},
		{
			// Regression: an ordinary clarifying question immediately
			// followed by the empty prompt returning — happens after nearly
			// every normal turn, must not read as a permission dialog just
			// because "❯" appears nearby.
			name:    "clarifying question immediately followed by empty prompt is idle",
			content: "⏺ Would you like me to continue with the refactor?\n\n❯ ",
			want:    AgentStatusIdle,
		},
		{
			name:    "do-you-want question immediately followed by empty prompt is idle",
			content: "⏺ Do you want me to look into this further?\n❯ ",
			want:    AgentStatusIdle,
		},
		{
			name:    "numbered Yes/No menu without box borders is still waiting",
			content: "Would you like to proceed?\n\n  1. Yes\n  2. No",
			want:    AgentStatusWaiting,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := detectClaudeStatus(c.content, AgentStatusIdle); got != c.want {
				t.Errorf("detectClaudeStatus(%q) = %v, want %v", c.content, got, c.want)
			}
		})
	}
}

func TestDetectClaudeStatusHoldsStatusOnTransientToggleHint(t *testing.T) {
	content := "some transcript line\nctrl+r to toggle verbose output"
	for _, prev := range []AgentStatus{AgentStatusBusy, AgentStatusWaiting, AgentStatusIdle} {
		if got := detectClaudeStatus(content, prev); got != prev {
			t.Errorf("detectClaudeStatus with prevStatus %v = %v, want unchanged", prev, got)
		}
	}
}

func TestDetectGeminiStatus(t *testing.T) {
	cases := []struct {
		name    string
		content string
		want    AgentStatus
	}{
		{"waiting confirmation", "Waiting for user confirmation...", AgentStatusWaiting},
		{"waiting apply change box", "│ Apply this change?", AgentStatusWaiting},
		{"busy esc to cancel", "Generating...\nesc to cancel", AgentStatusBusy},
		{"idle", "> ", AgentStatusIdle},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := detectGeminiStatus(c.content); got != c.want {
				t.Errorf("detectGeminiStatus(%q) = %v, want %v", c.content, got, c.want)
			}
		})
	}
}

func TestDetectCodexStatus(t *testing.T) {
	cases := []struct {
		name    string
		content string
		want    AgentStatus
	}{
		{"waiting confirm enter", "Press enter to confirm or esc to cancel", AgentStatusWaiting},
		{"waiting allow command", "Allow command?", AgentStatusWaiting},
		{"waiting y/n", "Run this command? [y/n]", AgentStatusWaiting},
		{"busy esc interrupt", "Working...\nesc to interrupt", AgentStatusBusy},
		{"idle", "codex>", AgentStatusIdle},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := detectCodexStatus(c.content); got != c.want {
				t.Errorf("detectCodexStatus(%q) = %v, want %v", c.content, got, c.want)
			}
		})
	}
}

func TestApplyIdleDebounceHoldsUntilStable(t *testing.T) {
	now := time.Now()
	prev := AgentState{Status: AgentStatusBusy, LastContent: "working...", StableSince: now}

	// Content just changed to an idle-looking frame: not enough time has
	// passed, so the previous status should be held.
	held := applyIdleDebounce(prev, "idle-looking frame", AgentStatusIdle, now.Add(10*time.Millisecond))
	if held.Status != AgentStatusBusy {
		t.Fatalf("expected debounce to hold busy status, got %v", held.Status)
	}

	// Once the debounce window has elapsed with stable content, idle is confirmed.
	confirmed := applyIdleDebounce(held, "idle-looking frame", AgentStatusIdle, now.Add(10*time.Millisecond+AgentIdleDebounce))
	if confirmed.Status != AgentStatusIdle {
		t.Fatalf("expected idle after debounce window, got %v", confirmed.Status)
	}
}

func TestApplyIdleDebounceImmediateForNonIdle(t *testing.T) {
	now := time.Now()
	prev := AgentState{Status: AgentStatusIdle, LastContent: "> ", StableSince: now}

	got := applyIdleDebounce(prev, "esc to interrupt", AgentStatusBusy, now.Add(time.Millisecond))
	if got.Status != AgentStatusBusy {
		t.Fatalf("expected immediate busy transition, got %v", got.Status)
	}
}

func TestLastLines(t *testing.T) {
	content := "1\n2\n3\n4\n5"
	if got := lastLines(content, 3); got != "3\n4\n5" {
		t.Errorf("lastLines(_, 3) = %q, want %q", got, "3\n4\n5")
	}
	if got := lastLines(content, 10); got != content {
		t.Errorf("lastLines(_, 10) should return content unchanged, got %q", got)
	}
}

func TestContentAbovePromptBox(t *testing.T) {
	content := "above line 1\nabove line 2\n─────\n❯ \n─────"
	want := "above line 1\nabove line 2"
	if got := contentAbovePromptBox(content, 30); got != want {
		t.Errorf("contentAbovePromptBox() = %q, want %q", got, want)
	}
}

func TestContentAbovePromptBoxFallsBackWithoutBox(t *testing.T) {
	content := "no box here\njust plain lines"
	if got := contentAbovePromptBox(content, 30); got != content {
		t.Errorf("expected fallback to full content, got %q", got)
	}
}

func TestRecentContentAbovePromptBoxTrimsTrailingBlanks(t *testing.T) {
	content := "✳ Simplifying…\nesc to interrupt\n\n\n─────\n❯ \n─────"
	got := recentContentAbovePromptBox(content, 30)
	if !strings.Contains(got, "esc to interrupt") {
		t.Errorf("expected recent block to retain the busy line, got %q", got)
	}
}

func TestParseAgentTaskLabel(t *testing.T) {
	cases := []struct {
		title string
		want  string
	}{
		{"✳ Debug invoice date filter logic", "Debug invoice date filter logic"},
		{"◑ Design AI CLI session management features", "Design AI CLI session management features"},
		{"zsh", "zsh"},
		{"", ""},
	}
	for _, c := range cases {
		if got := parseAgentTaskLabel(c.title); got != c.want {
			t.Errorf("parseAgentTaskLabel(%q) = %q, want %q", c.title, got, c.want)
		}
	}
}
