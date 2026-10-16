package main

import (
	"bytes"
	"fmt"
	"os"
	"os/signal"
	"regexp"
	"syscall"

	tea "github.com/charmbracelet/bubbletea"
	"golang.org/x/term"
)

// overwriteOutput repaints rows in place instead of erasing them first.
type overwriteOutput struct{ *os.File }

func (o overwriteOutput) Write(b []byte) (int, error) {
	if _, err := o.File.Write(overwriteFrame(b)); err != nil {
		return 0, err
	}
	return len(b), nil
}

var frameTail = regexp.MustCompile(`\x1b\[\d+;\d+H$`)

func overwriteFrame(b []byte) []byte {
	const erase, up, down = "\x1b[2K", "\x1b[1A", "\x1b[1B"
	var erased []bool // per up-move, whether the row was erased first
	var back []byte
	pending := false
	pos := 0
prefix:
	for pos < len(b) {
		rest := b[pos:]
		switch {
		case bytes.HasPrefix(rest, []byte(erase)):
			pending = true
			pos += len(erase)
		case bytes.HasPrefix(rest, []byte(up)):
			erased = append(erased, pending)
			pending = false
			pos += len(up)
		default:
			i := 2
			if len(rest) < 3 || rest[0] != 0x1b || rest[1] != '[' {
				break prefix
			}
			for i < len(rest) && rest[i] >= '0' && rest[i] <= '9' {
				i++
			}
			if i == 2 || i >= len(rest) || rest[i] != 'D' {
				break prefix
			}
			back = rest[:i+1]
			pos += i + 1
		}
	}
	if back == nil {
		return b // first paint or non-frame write
	}

	body := b[pos:]
	tail := frameTail.Find(body)
	body = body[:len(body)-len(tail)]
	painted := bytes.Count(body, []byte("\r\n")) + bytes.Count(body, []byte(down)) + 1
	lastStart := 0
	if i := bytes.LastIndex(body, []byte("\r\n")); i >= 0 {
		lastStart = i + 2
	}
	if i := bytes.LastIndex(body, []byte(down)); i >= 0 && i+len(down) > lastStart {
		lastStart = i + len(down)
	}
	lastPainted := lastStart < len(body)

	var out []byte
	rows := len(erased) + 1
	for k, wasErased := range erased {
		if wasErased && rows-1-k >= painted {
			out = append(out, erase...)
		}
		out = append(out, up...)
	}
	out = append(out, back...)
	body = bytes.ReplaceAll(body, []byte("\r\n"), []byte("\x1b[K\r\n"))
	out = append(out, body...)
	if lastPainted {
		out = append(out, "\x1b[K"...)
	}
	return append(out, tail...)
}

func forwardResizes(p *tea.Program, f *os.File) {
	send := func() {
		if w, h, err := term.GetSize(int(f.Fd())); err == nil {
			p.Send(tea.WindowSizeMsg{Width: w, Height: h})
		}
	}
	go send()
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGWINCH)
	go func() {
		for range ch {
			send()
		}
	}()
}

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

	p := tea.NewProgram(model{keys: defaultKeymap()}, tea.WithAltScreen(), tea.WithOutput(overwriteOutput{os.Stdout}))
	forwardResizes(p, os.Stdout)
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
