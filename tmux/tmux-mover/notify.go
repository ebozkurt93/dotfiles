package main

import "os/exec"

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
// notifySound; a missing tool or failed call is a silent no-op, consistent
// with notifySound.
func notifyBanner(title, subtitle, body, execute string) {
	if path, err := exec.LookPath("terminal-notifier"); err == nil {
		args := []string{"-title", title, "-subtitle", subtitle, "-message", body}
		if execute != "" {
			args = append(args, "-execute", execute)
		}
		_ = exec.Command(path, args...).Start()
		return
	}
	if path, err := exec.LookPath("osascript"); err == nil {
		_ = exec.Command(path,
			"-e", "on run argv",
			"-e", "display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)",
			"-e", "end run",
			title, subtitle, body,
		).Start()
		return
	}
	if path, err := exec.LookPath("notify-send"); err == nil {
		line := subtitle
		if body != "" {
			if line != "" {
				line += "\n"
			}
			line += body
		}
		_ = exec.Command(path, title, line).Start()
		return
	}
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
// on PATH; if none are found (or playback fails) it's a silent no-op rather
// than an error, since a missed notification sound shouldn't crash the
// watcher.
func notifySound() {
	for _, c := range soundCandidates {
		path, err := exec.LookPath(c.bin)
		if err != nil {
			continue
		}
		_ = exec.Command(path, c.args...).Start()
		return
	}
}
