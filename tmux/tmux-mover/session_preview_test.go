package main

import (
	"strings"
	"testing"
)

func TestMeaningfulLineCountTrimsTrailingBlanks(t *testing.T) {
	text := "one\ntwo\nthree\n\n\n"
	if got := meaningfulLineCount(text); got != 3 {
		t.Fatalf("expected 3 meaningful lines, got %d", got)
	}
}

func TestMeaningfulLineCountEmpty(t *testing.T) {
	if got := meaningfulLineCount("\n\n   \n"); got != 0 {
		t.Fatalf("expected 0 for all-blank text, got %d", got)
	}
}

func TestMeaningfulLineCountUncapped(t *testing.T) {
	lines := make([]string, 40)
	for i := range lines {
		lines[i] = "line"
	}
	text := strings.Join(lines, "\n")
	if got := meaningfulLineCount(text); got != 40 {
		t.Fatalf("expected uncapped count of 40, got %d", got)
	}
}

// TestSessionPreviewFitUsesFullNaturalSizeWhenItFits guards the original bug
// report: a session with plenty of preview panel space showed a fixed
// hard-capped snippet per pane instead of using the room available.
func TestSessionPreviewFitUsesFullNaturalSizeWhenItFits(t *testing.T) {
	natural := []int{20, 15}
	lines, shown := sessionPreviewFit(60, natural)
	if shown != 2 {
		t.Fatalf("expected both panes shown, got %d", shown)
	}
	if lines[0] != 20 || lines[1] != 15 {
		t.Fatalf("expected full natural sizes [20 15], got %v", lines)
	}
}

// TestSessionPreviewFitWaterFillsSinglePaneToFillPanel is the exact "you
// have all the space to show stuff, you show 2 lines" scenario: one busy
// pane in a tall panel should grow to use the space, not sit at the floor.
func TestSessionPreviewFitWaterFillsSinglePaneToFillPanel(t *testing.T) {
	natural := []int{500}
	previewHeight := 40
	lines, shown := sessionPreviewFit(previewHeight, natural)
	if shown != 1 {
		t.Fatalf("expected 1 pane shown, got %d", shown)
	}
	budget := previewHeight - 2
	wantLines := budget - sessionPreviewOverhead
	if lines[0] != wantLines {
		t.Fatalf("expected pane to grow to fill budget (%d lines), got %d", wantLines, lines[0])
	}
}

// TestSessionPreviewFitFloorNotTwo guards the "min 2 is too too low"
// feedback: a pane that must be clipped should never be clipped below
// minSessionPreviewLines.
func TestSessionPreviewFitFloorNotTwo(t *testing.T) {
	natural := make([]int, 20)
	for i := range natural {
		natural[i] = 50
	}
	lines, shown := sessionPreviewFit(30, natural)
	for i := 0; i < shown; i++ {
		if lines[i] < minSessionPreviewLines {
			t.Fatalf("pane %d clipped to %d lines, below floor %d", i, lines[i], minSessionPreviewLines)
		}
	}
}

// TestSessionPreviewFitReservesRoomForMoreNote is the exact bug from the
// screenshot: 6 panes' worth of content across 3 windows, with a preview
// panel too short to show them all. Water-filling must not spend the
// entire budget on shown panes, or the caller's "+N more pane(s) not
// shown" note gets silently sliced off by the preview panel's own
// height-based truncation.
func TestSessionPreviewFitReservesRoomForMoreNote(t *testing.T) {
	natural := []int{20, 20, 20, 20, 20, 20} // 6 busy panes, like support-bangerhead
	previewHeight := 20                      // short panel, forces a drop
	lines, shown := sessionPreviewFit(previewHeight, natural)
	if shown >= len(natural) {
		t.Fatalf("expected some panes dropped to exercise the reservation path, got shown=%d of %d", shown, len(natural))
	}

	used := 0
	for _, l := range lines {
		used += l + sessionPreviewOverhead
	}
	budget := previewHeight - 2
	noteCost := sessionPreviewOverhead // blank line + note text line
	if used > budget-noteCost {
		t.Fatalf("shown panes used %d of %d budget, leaving < %d lines for the \"+N more\" note", used, budget, noteCost)
	}
}

func TestSessionPreviewFitEmptyInput(t *testing.T) {
	lines, shown := sessionPreviewFit(40, nil)
	if lines != nil || shown != 0 {
		t.Fatalf("expected nil/0 for empty input, got %v/%d", lines, shown)
	}
}

// TestSessionPreviewFitAlwaysShowsAtLeastOnePane guards against a
// pathological budget that's smaller than even one pane's floor cost —
// the mosaic should still show something rather than nothing.
func TestSessionPreviewFitAlwaysShowsAtLeastOnePane(t *testing.T) {
	natural := []int{50, 50, 50}
	_, shown := sessionPreviewFit(1, natural)
	if shown < 1 {
		t.Fatalf("expected at least 1 pane shown even under a tiny budget, got %d", shown)
	}
}
