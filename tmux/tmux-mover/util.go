package main

import (
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/charmbracelet/x/ansi"
	"github.com/mattn/go-runewidth"
)

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func truncateRow(s string, width int) string {
	if width <= 0 {
		return ""
	}
	if runewidth.StringWidth(s) <= width {
		return s
	}
	if width <= 3 {
		return runewidth.Truncate(s, width, "")
	}
	return runewidth.Truncate(s, width, "...")
}

func sliceRows(rows []string, start int, maxRows int) []string {
	if len(rows) <= maxRows {
		return rows
	}
	if start < 0 {
		start = 0
	}
	end := start + maxRows
	if end > len(rows) {
		end = len(rows)
		start = max(0, end-maxRows)
	}
	return rows[start:end]
}

func truncatePreview(text string, width int, height int) string {
	if width <= 0 || height <= 0 {
		return ""
	}
	lines := strings.Split(strings.TrimRight(text, "\n"), "\n")
	if len(lines) > height {
		lines = lines[:height]
	}
	for i, line := range lines {
		lines[i] = ansi.Truncate(line, width, "") + "\x1b[0m"
	}
	return strings.Join(lines, "\n")
}

// trimTrailingBlankLines strips a pane capture's trailing padding rows (a
// pane shorter than the terminal is padded with blank lines to fill it) so
// callers can measure/display only the actual content, e.g. an idle prompt
// near the top of an otherwise-blank pane.
func trimTrailingBlankLines(text string) string {
	trimmed := strings.TrimRight(text, "\n")
	if strings.TrimSpace(trimmed) == "" {
		return ""
	}
	lines := strings.Split(trimmed, "\n")
	end := len(lines)
	for end > 0 && strings.TrimSpace(lines[end-1]) == "" {
		end--
	}
	return strings.Join(lines[:end], "\n")
}

// lastNLines keeps only the trailing n lines of text (the most recent
// terminal output), so a mosaic of several panes' captures can fit each one
// into a fixed line budget instead of one busy pane's full screen crowding
// the others out.
func lastNLines(text string, n int) string {
	if n <= 0 {
		return ""
	}
	lines := strings.Split(strings.TrimRight(text, "\n"), "\n")
	if len(lines) <= n {
		return strings.Join(lines, "\n")
	}
	return strings.Join(lines[len(lines)-n:], "\n")
}

func truncateANSI(s string, width int) string {
	if width <= 0 {
		return ""
	}
	return ansi.Truncate(s, width, "")
}

func padRight(s string, width int) string {
	if width <= 0 {
		return ""
	}
	if runewidth.StringWidth(s) >= width {
		return s
	}
	return s + strings.Repeat(" ", width-runewidth.StringWidth(s))
}

func padRightANSI(s string, width int) string {
	if width <= 0 {
		return ""
	}
	current := ansi.StringWidth(s)
	if current >= width {
		return s
	}
	return s + strings.Repeat(" ", width-current)
}

func deleteLastWord(s string) string {
	isWordChar := func(r rune) bool {
		return unicode.IsLetter(r) || unicode.IsDigit(r)
	}
	i := len(s)
	for i > 0 {
		r, size := utf8.DecodeLastRuneInString(s[:i])
		if isWordChar(r) {
			break
		}
		i -= size
	}
	for i > 0 {
		r, size := utf8.DecodeLastRuneInString(s[:i])
		if !isWordChar(r) {
			break
		}
		i -= size
	}
	return s[:i]
}

func sectionRule(width int) string {
	return strings.Repeat("─", max(1, width-2))
}

func selectPaneIndex(order []string, paneID string, fallback int) int {
	if paneID != "" {
		for idx, id := range order {
			if id == paneID {
				return idx
			}
		}
	}
	if fallback >= 0 && fallback < len(order) {
		return fallback
	}
	return 0
}
