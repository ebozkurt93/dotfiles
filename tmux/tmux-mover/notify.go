package main

import "os/exec"

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
