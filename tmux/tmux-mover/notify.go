package main

import (
	"fmt"
	"os/exec"
	"strings"
)

// notifyBanner shows an OS notification banner with title/subtitle/body, so
// an agent state change is visible even when the machine is muted. All three
// are passed as argv to the underlying tool rather than interpolated into a
// script string, so untrusted content (e.g. a pane's title/task, which the
// CLI itself controls) can't break out of the notification text.
//
// execute, if non-empty, is run (via terminal-notifier's -execute, itself
// invoked through /bin/sh -c) when the banner is clicked — only
// terminal-notifier supports this; it's silently dropped on the
// osascript/notify-send fallback paths below, which have no click-action
// support at all.
//
// terminal-notifier is tried first on macOS (installed via nix, see
// packages.nix) since it renders title/subtitle/body natively via flags with
// no scripting involved; osascript is the fallback if it's not installed.
// notify-send (Linux/libnotify) has no subtitle concept, so subtitle and
// body are folded into one line there. Same auto-detect-by-PATH approach as
// notifySound.
//
// Unlike a bare Start(), this runs the tool synchronously (CombinedOutput)
// and returns what happened — the watcher logs the result of every attempt,
// since a banner that silently fails to display (wrong permissions, dead
// notification daemon, etc.) with no trace is exactly the kind of gap this
// is meant to catch. "no notifier binary found" is reported as an error too
// rather than a silent no-op, for the same reason.
func notifyBanner(title, subtitle, body, execute string) (tool string, err error) {
	if path, lookErr := exec.LookPath("terminal-notifier"); lookErr == nil {
		args := []string{"-title", title, "-subtitle", subtitle, "-message", body}
		if execute != "" {
			args = append(args, "-execute", execute)
		}
		out, runErr := exec.Command(path, args...).CombinedOutput()
		return "terminal-notifier", wrapNotifyOutput(runErr, out)
	}
	if path, lookErr := exec.LookPath("osascript"); lookErr == nil {
		out, runErr := exec.Command(path,
			"-e", "on run argv",
			"-e", "display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)",
			"-e", "end run",
			title, subtitle, body,
		).CombinedOutput()
		return "osascript", wrapNotifyOutput(runErr, out)
	}
	if path, lookErr := exec.LookPath("notify-send"); lookErr == nil {
		line := subtitle
		if body != "" {
			if line != "" {
				line += "\n"
			}
			line += body
		}
		out, runErr := exec.Command(path, title, line).CombinedOutput()
		return "notify-send", wrapNotifyOutput(runErr, out)
	}
	return "", fmt.Errorf("no notifier binary found on PATH (tried terminal-notifier, osascript, notify-send)")
}

// wrapNotifyOutput folds a notifier command's combined stdout+stderr into
// its error, if any, so the caller's log line carries the actual failure
// reason instead of just an exit code.
func wrapNotifyOutput(err error, out []byte) error {
	if err == nil {
		return nil
	}
	if len(out) == 0 {
		return err
	}
	return fmt.Errorf("%w: %s", err, strings.TrimSpace(string(out)))
}

// soundCandidate is one (command, args) pair notifySound tries in order. Kept
// as full commands rather than just binary names since the sound file/arg
// shape differs per player.
type soundCandidate struct {
	bin  string
	args []string
}

// soundCandidates lists players to probe, macOS first then the common Linux
// sound servers/players, so notifySound works on either platform without a
// build tag or runtime.GOOS switch.
var soundCandidates = []soundCandidate{
	{"afplay", []string{"/System/Library/Sounds/Glass.aiff"}},
	{"paplay", []string{"/usr/share/sounds/freedesktop/stereo/complete.oga"}},
	{"pw-play", []string{"/usr/share/sounds/freedesktop/stereo/complete.oga"}},
	{"canberra-gtk-play", []string{"-i", "complete"}},
}

// notifySound plays a short system sound to flag an agent state change. It
// tries each soundCandidate in order and uses the first one whose binary is
// on PATH. A missed notification sound doesn't crash the watcher, but
// (unlike before) the outcome is reported rather than discarded, so the
// watcher can log it.
func notifySound() (tool string, err error) {
	for _, c := range soundCandidates {
		path, lookErr := exec.LookPath(c.bin)
		if lookErr != nil {
			continue
		}
		out, runErr := exec.Command(path, c.args...).CombinedOutput()
		return c.bin, wrapNotifyOutput(runErr, out)
	}
	return "", fmt.Errorf("no sound player found on PATH")
}
