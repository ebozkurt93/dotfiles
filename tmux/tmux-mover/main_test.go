package main

import "testing"

func TestOverwriteFrameKeepsRowsAndErasesOnlyStaleOnes(t *testing.T) {
	in := "\x1b[2K\x1b[1A\x1b[2K\x1b[1A\x1b[80D\x1b[2Kone\r\ntwo\x1b[3;1H"
	want := "\x1b[2K\x1b[1A\x1b[1A\x1b[80Done\x1b[K\r\ntwo\x1b[K\x1b[3;1H"
	if got := string(overwriteFrame([]byte(in))); got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func TestOverwriteFrameSkippedLastRowIsNotCleared(t *testing.T) {
	in := "\x1b[1A\x1b[80D\x1b[2Kone\r\n\x1b[1B\x1b[2;1H"
	want := "\x1b[1A\x1b[80Done\x1b[K\r\n\x1b[1B\x1b[2;1H"
	if got := string(overwriteFrame([]byte(in))); got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
}

func TestOverwriteFramePassesThroughNonFrames(t *testing.T) {
	for _, in := range []string{"\x1b[?1049h", "first\r\npaint", ""} {
		if got := string(overwriteFrame([]byte(in))); got != in {
			t.Fatalf("got %q, want %q", got, in)
		}
	}
}
