package main

import (
	"os/exec"
	"regexp"
	"strings"
	"time"
)

type AgentKind int

const (
	AgentNone AgentKind = iota
	AgentClaude
	AgentGemini
	AgentCodex
)

func (k AgentKind) Label() string {
	switch k {
	case AgentClaude:
		return "Claude"
	case AgentGemini:
		return "Gemini"
	case AgentCodex:
		return "Codex"
	default:
		return ""
	}
}

// Slug is a lowercase, script-friendly form of Label (e.g. "claude"), used in
// the --json CLI output.
func (k AgentKind) Slug() string {
	return strings.ToLower(k.Label())
}

type AgentStatus int

const (
	AgentStatusUnknown AgentStatus = iota
	AgentStatusIdle
	AgentStatusBusy
	AgentStatusWaiting
)

func (s AgentStatus) String() string {
	switch s {
	case AgentStatusIdle:
		return "idle"
	case AgentStatusBusy:
		return "busy"
	case AgentStatusWaiting:
		return "waiting"
	default:
		return "unknown"
	}
}

// AgentIdleDebounce mirrors ccmanager's IDLE_DEBOUNCE_MS: Claude Code (and,
// defensively, the other CLIs) sometimes renders idle-looking frames mid-turn,
// so a busy->idle transition is only confirmed once content has been
// unchanged for this long.
const AgentIdleDebounce = 1500 * time.Millisecond

type AgentState struct {
	Kind        AgentKind
	Status      AgentStatus
	Task        string
	LastContent string
	StableSince time.Time
	PID         string
	// HasBackgroundJob is orthogonal to Status: Status reflects exactly what's
	// rendered on screen right now (so "idle" still means "you can type"),
	// while this tracks whether a run_in_background Bash-tool task is still
	// alive in the pane's process tree (see paneHasActiveBackgroundTask) even
	// after the foreground turn that started it has ended and the render
	// looks idle.
	HasBackgroundJob bool
	// KindConfirmedAt is the last time this pane's Kind was actually
	// re-derived from pane_current_command (or a process-tree probe) rather
	// than just carried over from the previous tick. reconcileAgentStates
	// uses it to give a pane a short grace period (agentKindGracePeriod)
	// before dropping its whole AgentState — including Status — the instant
	// a single tick fails to classify it, which would otherwise silently
	// reset prevStatus to Unknown and swallow any transition straddling that
	// gap (see shouldNotifyAgentTransition's fresh-pane check).
	KindConfirmedAt time.Time
	// Unseen marks a pane whose most recent notify-worthy transition (see
	// shouldNotifyAgentTransition — finished, or started waiting for input)
	// hasn't yet been observed: either by looking at the actual tmux pane
	// (see tmux.go's currentlyViewedPaneIDs, checked by the --watch-agents
	// loop regardless of whether tmux-mover's own TUI is open) or, in the
	// TUI, by having it visible in the agent dashboard. UnseenSince is when
	// it was set, so consumers can sort/age it.
	Unseen      bool
	UnseenSince time.Time
}

// agentKindGracePeriod is how long reconcileAgentStates keeps a pane's
// AgentState alive after a tick fails to classify it, before actually
// treating it as gone. Covers a transient pane_current_command misread or a
// slow ps/pgrep call without masking a pane that's genuinely no longer
// running an agent for more than a few ticks.
const agentKindGracePeriod = 5 * time.Second

// probeRetryInterval bounds how often reconcileAgentStates re-runs
// probeAgentKindByProcessTree against a pane whose pane_current_command is
// an ambiguous runtime (agents.go's isAmbiguousRuntimeCommand) but hasn't
// resolved to a known CLI yet. Without this, a single failed probe — e.g.
// racing the CLI's own child process forking under `node` right at startup —
// used to be cached as final forever (see reconcileAgentStates), silently
// hiding that pane from detection for its entire lifetime.
const probeRetryInterval = 3 * time.Second

// probeRecord tracks, per pane ID, the pane_current_command value
// reconcileAgentStates last probed against and when — so a still-unresolved
// ambiguous pane gets re-probed periodically instead of exactly once.
type probeRecord struct {
	command string
	lastTry time.Time
}

func detectAgentKind(command string) AgentKind {
	return matchAgentKindInText(command)
}

func matchAgentKindInText(text string) AgentKind {
	lower := strings.ToLower(text)
	switch {
	case strings.Contains(lower, "claude"):
		return AgentClaude
	case strings.Contains(lower, "gemini"):
		return AgentGemini
	case strings.Contains(lower, "codex"):
		return AgentCodex
	default:
		return AgentNone
	}
}

// isAmbiguousRuntimeCommand reports whether pane_current_command is a
// generic language runtime rather than the CLI's own binary name. Some
// installs (e.g. Gemini CLI via its npm/node entrypoint, unlike Claude
// Code's nix wrapper which renames argv0) leave tmux reporting the
// interpreter instead of the tool, so a plain substring match on the
// command name alone misses them entirely.
func isAmbiguousRuntimeCommand(command string) bool {
	switch strings.ToLower(command) {
	case "node", "bun", "deno", "python", "python3":
		return true
	default:
		return false
	}
}

// matchAgentKindInCommandLines substring-matches full process command lines
// (as opposed to the short process name tmux reports) — used against a
// pane's descendant processes to see past a generic runtime wrapper.
func matchAgentKindInCommandLines(lines []string) AgentKind {
	for _, line := range lines {
		if kind := matchAgentKindInText(line); kind != AgentNone {
			return kind
		}
	}
	return AgentNone
}

// probeAgentKindByProcessTree looks one level below the pane's shell for a
// child process whose full command line (not just its short name) names a
// known CLI — the fallback for isAmbiguousRuntimeCommand cases. It's only
// meant to run occasionally against panes reconcileAgentStates hasn't
// resolved yet, since it spawns pgrep/ps.
func probeAgentKindByProcessTree(pid string) AgentKind {
	if pid == "" {
		return AgentNone
	}
	childOut, err := exec.Command("pgrep", "-P", pid).Output()
	if err != nil {
		return AgentNone
	}
	childPIDs := strings.Fields(string(childOut))
	if len(childPIDs) == 0 {
		return AgentNone
	}
	cmdOut, err := exec.Command("ps", "-o", "command=", "-p", strings.Join(childPIDs, ",")).Output()
	if err != nil {
		return AgentNone
	}
	return matchAgentKindInCommandLines(strings.Split(string(cmdOut), "\n"))
}

// claudeBackgroundTaskMarker matches Claude Code's own Bash-tool wrapper
// invocation (source .../.claude/shell-snapshots/snapshot-*.sh && ...),
// which it spawns as a child process for every Bash tool call. A foreground
// call already renders "esc to interrupt" while it runs, but a call made
// with run_in_background keeps this child process alive after Claude's own
// turn ends and its render goes fully idle — this is the only signal left
// at that point, which is why detectAgentStatus's text-based checks alone
// can't tell "genuinely idle" apart from "turn ended, background task still
// running".
const claudeBackgroundTaskMarker = "shell-snapshots"

// claudeBackgroundAgentWaiting matches Claude Code's own idle-but-waiting
// footer ("✻ Waiting for 1 background agent to finish…"), rendered once the
// foreground turn has ended but a background Agent-tool subagent is still
// running. Unlike a run_in_background Bash task, a subagent has no local
// process to find via paneHasActiveBackgroundTask (it runs server-side), so
// this is the only signal available for it — a plain text match on the
// pane's content rather than a process-tree walk.
var claudeBackgroundAgentWaiting = regexp.MustCompile(`(?i)waiting for \d+ background agents? to finish`)

// contentHasBackgroundAgentJob reports whether the pane's content shows
// Claude Code's own "waiting for N background agent(s)" marker.
func contentHasBackgroundAgentJob(content string) bool {
	return claudeBackgroundAgentWaiting.MatchString(lastLines(content, 30))
}

// process is one row of `ps -eo pid,ppid,command` output.
type process struct {
	pid     string
	ppid    string
	command string
}

// listProcesses snapshots every process on the machine in one `ps` call, so
// paneHasActiveBackgroundTask can walk the tree for as many panes as needed
// against a single, consistent snapshot instead of spawning ps per pane.
func listProcesses() ([]process, error) {
	out, err := exec.Command("ps", "-eo", "pid,ppid,command").Output()
	if err != nil {
		return nil, err
	}
	lines := strings.Split(string(out), "\n")
	procs := make([]process, 0, len(lines))
	for _, line := range lines[1:] { // skip header
		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		procs = append(procs, process{pid: fields[0], ppid: fields[1], command: strings.Join(fields[2:], " ")})
	}
	return procs, nil
}

// paneHasActiveBackgroundTask reports whether any descendant of the pane's
// shell process (walking the whole subtree, not just direct children, since
// Claude Code's wrapper can be nested a level or two deep) matches
// claudeBackgroundTaskMarker — i.e. whether Claude Code has a background
// Bash-tool task still running in that pane, regardless of what's currently
// rendered on screen.
func paneHasActiveBackgroundTask(procs []process, shellPID string) bool {
	if shellPID == "" {
		return false
	}
	childrenOf := map[string][]process{}
	for _, p := range procs {
		childrenOf[p.ppid] = append(childrenOf[p.ppid], p)
	}
	queue := childrenOf[shellPID]
	for len(queue) > 0 {
		p := queue[0]
		queue = queue[1:]
		if strings.Contains(p.command, claudeBackgroundTaskMarker) {
			return true
		}
		queue = append(queue, childrenOf[p.pid]...)
	}
	return false
}

// Ported from kbwo/ccmanager (src/services/stateDetector/claude.ts).
var (
	claudeSpinnerChars   = "✱✲✳✴✵✶✷✸✹✺✻✼✽✾✿❀❁❂❃❇❈❉❊❋✢✣✤✥✦✧✨⊛⊕⊙◉◎◍⁂⁕※⍟☼★☆·•⏺▸▹∙⋅○●"
	claudeSpinnerPattern = regexp.MustCompile(`(?m)^[` + regexp.QuoteMeta(claudeSpinnerChars) + `] \S+ing.*\x{2026}`)
	claudeTokenStatsLine = regexp.MustCompile(`(?i)\([^)]*\d[^)]*tokens\s*\)`)
	// Requires an actual NUMBERED option (e.g. "1. Yes") within a few lines
	// of the trigger phrase — not just the bare word "yes" or the bare "❯"
	// cursor, both of which also show up in completely ordinary places: "❯"
	// is also just the normal empty-input prompt marker, and an assistant
	// asking a genuine clarifying question ("Would you like me to
	// continue?") is immediately followed by that same empty prompt after
	// nearly every turn. A real permission dialog renders as an actual
	// menu, which this now requires.
	claudeWantsPrompt = regexp.MustCompile(`(?is)(?:do you want|would you like)[^\n]*(?:\n[^\n]*){0,4}?[❯>]?\s*\d+\.\s*(?:yes|allow|no|deny)\b`)
	claudeDenyMenu    = regexp.MustCompile(`\d+\.\s*deny\s*\(esc\)`)
	// Anchored to the start of a line (allowing leading padding) since the
	// real search-overlay UI renders "⌕ Search…" as its own line — an
	// unanchored substring match also fires when that exact phrase shows up
	// mid-sentence in ordinary chat/code content (e.g. someone's transcript
	// literally discussing this feature by name).
	claudeSearchOverlay = regexp.MustCompile(`(?m)^\s*⌕ Search`)
	// A line that's entirely "─" (the prompt-box border), vs. claudeBorderishLine
	// below which also tolerates "-" and stray whitespace — ccmanager's
	// /^─+$/ and /^[-─\s]+$/ respectively.
	claudeBorderLine    = regexp.MustCompile(`^─+$`)
	claudeBorderishLine = regexp.MustCompile(`^[-─\s]+$`)

	geminiWaitingBox  = []string{"│ Apply this change", "│ Allow execution", "│ Do you want to proceed"}
	geminiWantsPrompt = regexp.MustCompile(`(?is)(allow execution|do you want to|apply this change)[^\n]*(?:\n[^\n]*){0,3}?\byes\b`)

	codexConfirmEnter = regexp.MustCompile(`(?i)confirm with .+ enter`)
	codexWantsPrompt  = regexp.MustCompile(`(?is)(do you want|would you like)[^\n]*(?:\n[^\n]*){0,3}?\byes\b`)
	codexEscInterrupt = regexp.MustCompile(`(?i)esc.*interrupt`)
)

// lastLines returns at most the last n lines of content — ccmanager's
// getTerminalContent(terminal, n): every check below operates on a small,
// fixed-size tail window rather than the entire capture, specifically so a
// phrase near the top of a long pane can't pair up with an unrelated marker
// (like the next ordinary "❯" prompt) far below it. Trailing blank lines are
// dropped first: unlike ccmanager's node-pty buffer, tmux's capture-pane
// reports the full pane height, so a pane taller than its actual content
// pads the capture with blank lines below whatever was last drawn — without
// trimming those, the "last n lines" window would land on empty padding
// instead of the real content.
func lastLines(content string, n int) string {
	lines := strings.Split(content, "\n")
	end := len(lines)
	for end > 0 && strings.TrimSpace(lines[end-1]) == "" {
		end--
	}
	lines = lines[:end]
	if len(lines) <= n {
		return strings.Join(lines, "\n")
	}
	return strings.Join(lines[len(lines)-n:], "\n")
}

// contentAbovePromptBox ports ccmanager's getContentAbovePromptBox: within
// the last maxLines lines, find the input box (delimited by two "────"
// border lines, scanning from the bottom up) and return everything above
// it. Falls back to the full window if no box is found.
func contentAbovePromptBox(content string, maxLines int) string {
	lines := strings.Split(lastLines(content, maxLines), "\n")
	borderCount := 0
	for i := len(lines) - 1; i >= 0; i-- {
		trimmed := strings.TrimSpace(lines[i])
		if trimmed != "" && claudeBorderLine.MatchString(trimmed) {
			borderCount++
			if borderCount == 2 {
				return strings.Join(lines[:i], "\n")
			}
		}
	}
	return strings.Join(lines, "\n")
}

// recentContentAbovePromptBox ports ccmanager's
// getRecentContentAbovePromptBox: Claude Code redraws its lower pane with
// cursor-addressed updates, which can leave transient fragments outside the
// latest visible block, so busy-detection should only look at the most
// recent contiguous block directly above the prompt box — trim trailing
// blank/border/lone-"❯" lines, then walk back to the start of that block.
func recentContentAbovePromptBox(content string, maxLines int) string {
	lines := strings.Split(contentAbovePromptBox(content, maxLines), "\n")

	isBorderish := func(s string) bool {
		return s == "" || s == "❯" || claudeBorderishLine.MatchString(s)
	}
	for len(lines) > 0 {
		trimmed := strings.TrimSpace(lines[len(lines)-1])
		if isBorderish(trimmed) {
			lines = lines[:len(lines)-1]
			continue
		}
		break
	}
	if len(lines) == 0 {
		return ""
	}

	start := len(lines) - 1
	for start >= 0 {
		trimmed := strings.TrimSpace(lines[start])
		if trimmed == "" || claudeBorderishLine.MatchString(trimmed) {
			start++
			break
		}
		start--
	}
	if start < 0 {
		start = 0
	}
	return strings.Join(lines[start:], "\n")
}

// detectClaudeStatus classifies the pane's captured screen content,
// following ccmanager's ClaudeStateDetector.detectState flow: cap to the
// last 30 lines for the waiting-input checks, then narrow further to just
// the content above the prompt box for busy-detection, so distant/unrelated
// text can't pair up across the whole capture. prevStatus is returned
// unchanged for transient/ambiguous frames (like the "ctrl+r to toggle"
// hint) that don't themselves indicate a state change, so a fleeting render
// doesn't bounce the pane into AgentStatusUnknown.
func detectClaudeStatus(content string, prevStatus AgentStatus) AgentStatus {
	// Claude's file-search overlay ("⌕ Search…") also shows "esc to cancel",
	// which would otherwise match the waiting-for-input check below — but
	// it's a modal search box, not something blocking on you, so it's
	// checked first (against a wider 200-line window, per ccmanager) and
	// always counts as idle.
	if claudeSearchOverlay.MatchString(lastLines(content, 200)) {
		return AgentStatusIdle
	}

	fullContent := lastLines(content, 30)
	lower := strings.ToLower(fullContent)

	if strings.Contains(lower, "ctrl+r to toggle") {
		return prevStatus
	}

	if claudeWantsPrompt.MatchString(lower) {
		return AgentStatusWaiting
	}
	if strings.Contains(lower, "esc to cancel") {
		return AgentStatusWaiting
	}
	if claudeDenyMenu.MatchString(lower) {
		return AgentStatusWaiting
	}

	above := recentContentAbovePromptBox(content, 30)
	aboveLower := strings.ToLower(above)

	if strings.Contains(aboveLower, "esc to interrupt") || strings.Contains(aboveLower, "ctrl+c to interrupt") {
		return AgentStatusBusy
	}
	if claudeSpinnerPattern.MatchString(above) {
		return AgentStatusBusy
	}
	if claudeTokenStatsLine.MatchString(above) {
		return AgentStatusBusy
	}

	return AgentStatusIdle
}

func detectGeminiStatus(content string) AgentStatus {
	lower := strings.ToLower(content)

	if strings.Contains(lower, "waiting for user confirmation") {
		return AgentStatusWaiting
	}
	for _, marker := range geminiWaitingBox {
		if strings.Contains(content, marker) {
			return AgentStatusWaiting
		}
	}
	if geminiWantsPrompt.MatchString(lower) {
		return AgentStatusWaiting
	}

	if strings.Contains(lower, "esc to cancel") {
		return AgentStatusBusy
	}

	return AgentStatusIdle
}

func detectCodexStatus(content string) AgentStatus {
	lower := strings.ToLower(content)

	if strings.Contains(lower, "press enter to confirm or esc to cancel") || codexConfirmEnter.MatchString(content) {
		return AgentStatusWaiting
	}
	if strings.Contains(lower, "| enter to submit answer") {
		return AgentStatusWaiting
	}
	if strings.Contains(lower, "allow command?") || strings.Contains(lower, "[y/n]") ||
		strings.Contains(lower, "yes (y)") || strings.Contains(lower, "enter to submit") {
		return AgentStatusWaiting
	}
	if codexWantsPrompt.MatchString(lower) {
		return AgentStatusWaiting
	}

	if codexEscInterrupt.MatchString(lower) {
		return AgentStatusBusy
	}

	return AgentStatusIdle
}

func detectAgentStatus(kind AgentKind, content string, prevStatus AgentStatus) AgentStatus {
	switch kind {
	case AgentClaude:
		return detectClaudeStatus(content, prevStatus)
	case AgentGemini:
		return detectGeminiStatus(content)
	case AgentCodex:
		return detectCodexStatus(content)
	default:
		return AgentStatusUnknown
	}
}

// applyIdleDebounce ports ccmanager's debounceIdle: a raw busy->idle read is
// only trusted once the pane has stopped changing for AgentIdleDebounce. Any
// other status (busy/waiting) is trusted immediately. settleKey is what
// "changing" is measured against — see settleKey() below; it's usually the
// full pane content, but for a Claude pane with a title glyph it's just that
// glyph, since Claude redraws it every frame while a turn is in progress and
// freezes it once the turn ends.
func applyIdleDebounce(prev AgentState, settleKey string, rawStatus AgentStatus, now time.Time) AgentState {
	next := prev
	next.Kind = prev.Kind

	if settleKey != prev.LastContent {
		next.LastContent = settleKey
		next.StableSince = now
	}

	if rawStatus != AgentStatusIdle {
		next.Status = rawStatus
		return next
	}

	if prev.Status == AgentStatusUnknown {
		next.Status = AgentStatusIdle
		return next
	}

	if now.Sub(next.StableSince) >= AgentIdleDebounce {
		next.Status = AgentStatusIdle
	} else {
		next.Status = prev.Status
	}
	return next
}

// parseAgentTaskLabel strips a leading spinner/status glyph and space from a
// pane title set by the CLI itself (e.g. "✳ Debug invoice date filter logic"),
// returning just the human task description.
func parseAgentTaskLabel(title string) string {
	title = strings.TrimSpace(title)
	if title == "" {
		return ""
	}
	runes := []rune(title)
	if len(runes) > 1 && runes[0] > 127 && runes[1] == ' ' {
		return strings.TrimSpace(string(runes[2:]))
	}
	return title
}

// titleGlyph extracts the leading status glyph from a pane title set by the
// CLI itself — the same leading-glyph convention parseAgentTaskLabel strips
// off — or "" if the title doesn't have one (no title yet, or a CLI that
// doesn't set this convention).
func titleGlyph(title string) string {
	title = strings.TrimSpace(title)
	if title == "" {
		return ""
	}
	runes := []rune(title)
	if len(runes) > 1 && runes[0] > 127 && runes[1] == ' ' {
		return string(runes[0])
	}
	return ""
}

// settleKey returns what applyIdleDebounce should treat as "the pane's
// current appearance" for busy/idle stability comparison. Claude Code
// redraws its title's leading glyph every frame while a turn is in progress
// and freezes it the instant the turn ends (verified live: a pane showed a
// rotating "◐"/"◑" mid-turn, then froze on a static glyph once settled) —
// comparing just that one character is a far smaller, more reliable surface
// than diffing the whole captured screen, which can be kept from ever
// settling by unrelated content elsewhere in the pane (e.g. a live
// token-count or elapsed-time line). Falls back to the full pane content for
// panes/CLIs without an observed title-glyph convention (Codex, Gemini, or a
// Claude pane with no title set yet).
func settleKey(kind AgentKind, title, content string) string {
	if kind == AgentClaude {
		if glyph := titleGlyph(title); glyph != "" {
			return glyph
		}
	}
	return content
}
