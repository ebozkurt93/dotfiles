package main

import "os/exec"

// notifyBanner shows an OS notification banner with title/message, so an
// agent state change is visible even when the machine is muted. title and
// message are passed as argv to the underlying tool rather than interpolated
// into a script string, so untrusted content (e.g. a pane's title/task,
// which the CLI itself controls) can't break out of the notification text.
//
// osascript is tried first (macOS); notify-send (Linux/libnotify) as a
// fallback — same auto-detect-by-PATH approach as notifySound. A missing
// tool or failed call is a silent no-op, consistent with notifySound.
func notifyBanner(title, message string) {
	if path, err := exec.LookPath("osascript"); err == nil {
		_ = exec.Command(path,
			"-e", "on run argv",
			"-e", "display notification (item 2 of argv) with title (item 1 of argv)",
			"-e", "end run",
			title, message,
		).Start()
		return
	}
	if path, err := exec.LookPath("notify-send"); err == nil {
		_ = exec.Command(path, title, message).Start()
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
