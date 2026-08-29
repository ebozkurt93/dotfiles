package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
)

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--agents-status":
			os.Exit(runStatusCLI(false))
		case "--agents-json":
			os.Exit(runStatusCLI(true))
		case "--watch-agents":
			os.Exit(runWatchAgents())
		case "--help", "-h":
			printUsage()
			os.Exit(0)
		}
	}

	p := tea.NewProgram(model{keys: defaultKeymap()}, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

// printUsage lists every non-TUI entry point with a one-line description and
// a runnable example — the flags themselves live in the switch above and in
// cli.go/watch.go; this is deliberately kept as one place to scan rather
// than scattered doc comments, since it's meant to answer "what CLI surface
// does this binary have" at a glance.
func printUsage() {
	fmt.Print(`tmux-mover — tmux session/window/pane mover with AI-agent monitoring

Usage:
  tmux-mover                Launch the interactive TUI.
  tmux-mover --watch-agents Run headless: poll tmux for AI-CLI panes (Claude/
                             Gemini/Codex) and fire a sound + OS notification
                             banner on status changes (waiting for input,
                             finished). Meant to be started once in the
                             background, e.g. via 'make watch-start'; the TUI
                             does its own live detection independently and
                             doesn't require this to be running.
                               $ tmux-mover --watch-agents &
                             Notification delivery is controlled live through
                             tmux option @tmux-mover-notify:
                               $ tmux set -g @tmux-mover-notify off
                             Values: all (default), banner, sound, off.

  tmux-mover --agents-status One-line human-readable summary of AI-CLI pane
                             status across all tmux sessions. Prefers the
                             --watch-agents loop's persisted snapshot when
                             fresh, else does a live one-shot read. Meant for
                             a tmux status-bar segment.
                               $ tmux-mover --agents-status
                               2 working, 1 waiting for input

  tmux-mover --agents-json  Same data as --agents-status, as structured JSON
                             (per-pane kind/status/task/session/location/
                             background-job) plus aggregate counts. Meant for
                             scripting.
                               $ tmux-mover --agents-json | jq '.counts'
                               $ tmux-mover --agents-json | jq -r \
                                   '.panes[] | select(.status=="waiting") | .pane_id'

  tmux-mover --help         Show this message.
`)
}
