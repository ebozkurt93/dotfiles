package main

import (
	"strings"

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
