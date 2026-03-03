package main

import (
	"bytes"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

type TmuxRunner interface {
	Run(args ...string) (string, error)
}

type execRunner struct{}

func (r execRunner) Run(args ...string) (string, error) {
	cmd := exec.Command("tmux", args...)
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if stderr.Len() > 0 {
			return "", fmt.Errorf("tmux %s: %s", strings.Join(args, " "), strings.TrimSpace(stderr.String()))
		}
		return "", err
	}

	return stdout.String(), nil
}

var tmuxRunner TmuxRunner = execRunner{}

type Session struct {
	ID   string
	Name string
}

type Window struct {
	ID        string
	SessionID string
	Index     string
	IndexNum  int
	Name      string
}

type Pane struct {
	ID        string
	WindowID  string
	SessionID string
	IndexNum  int
	Path      string
	Command   string
	Title     string
}

type TmuxState struct {
	Sessions []Session
	Windows  []Window
	Panes    []Pane
}

func loadTmuxState() (TmuxState, error) {
	sessions, err := listSessions()
	if err != nil {
		return TmuxState{}, err
	}

	windows, err := listWindows()
	if err != nil {
		return TmuxState{}, err
	}

	panes, err := listPanes()
	if err != nil {
		return TmuxState{}, err
	}

	return TmuxState{
		Sessions: sessions,
		Windows:  windows,
		Panes:    panes,
	}, nil
}

func listSessions() ([]Session, error) {
	out, err := tmuxOutput("list-sessions", "-F", "#{session_id}\t#{session_name}")
	if err != nil {
		return nil, err
	}
	return parseSessionsOutput(out), nil
}

func listWindows() ([]Window, error) {
	out, err := tmuxOutput("list-windows", "-a", "-F", "#{window_id}\t#{session_id}\t#{window_index}\t#{window_name}")
	if err != nil {
		return nil, err
	}
	return parseWindowsOutput(out), nil
}

func listPanes() ([]Pane, error) {
	out, err := tmuxOutput("list-panes", "-a", "-F", "#{pane_id}\t#{window_id}\t#{session_id}\t#{pane_index}\t#{pane_current_path}\t#{pane_current_command}\t#{pane_title}")
	if err != nil {
		return nil, err
	}
	return parsePanesOutput(out), nil
}

func tmuxOutput(args ...string) (string, error) {
	return tmuxRunner.Run(args...)
}

func capturePane(paneID string) (string, error) {
	if paneID == "" {
		return "", nil
	}
	out, err := tmuxOutput("capture-pane", "-p", "-e", "-J", "-t", paneID)
	if err != nil {
		return "", err
	}
	return out, nil
}

func currentTmuxPaneID() (string, error) {
	out, err := tmuxOutput("display-message", "-p", "#{pane_id}")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}

func currentTmuxSessionID() (string, error) {
	out, err := tmuxOutput("display-message", "-p", "#{session_id}")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}

func currentTmuxWindowID() (string, error) {
	out, err := tmuxOutput("display-message", "-p", "#{window_id}")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}

func currentTmuxClientID() (string, error) {
	out, err := tmuxOutput("display-message", "-p", "#{client_id}")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}

func currentTmuxWindowPopup() (bool, error) {
	out, err := tmuxOutput("display-message", "-p", "#{window_popup}")
	if err != nil {
		return false, err
	}
	return strings.TrimSpace(out) == "1", nil
}

func switchClientToSession(sessionID string, clientID string) error {
	if sessionID == "" {
		return fmt.Errorf("missing session")
	}
	if clientID != "" {
		_, err := tmuxOutput("switch-client", "-c", clientID, "-t", sessionID)
		return err
	}
	_, err := tmuxOutput("switch-client", "-t", sessionID)
	return err
}

func applyPaneMove(action StagedAction) error {
	if action.SourceID == "" || action.TargetID == "" {
		return fmt.Errorf("missing pane or window target")
	}
	_, err := tmuxOutput("join-pane", "-d", "-s", action.SourceID, "-t", action.TargetID)
	return err
}

func applyWindowMove(action StagedAction) error {
	if action.SourceID == "" || action.TargetID == "" {
		return fmt.Errorf("missing window or session target")
	}
	_, err := tmuxOutput("move-window", "-d", "-s", action.SourceID, "-t", action.TargetID)
	return err
}

func applySessionCreate(name string) error {
	args := []string{"new-session", "-d"}
	if strings.TrimSpace(name) != "" {
		args = append(args, "-s", name)
	}
	_, err := tmuxOutput(args...)
	return err
}

func applyPaneKill(paneID string) error {
	if paneID == "" {
		return fmt.Errorf("missing pane")
	}
	_, err := tmuxOutput("kill-pane", "-t", paneID)
	return err
}

func applyPaneBreak(paneID string) error {
	if paneID == "" {
		return fmt.Errorf("missing pane")
	}
	_, err := tmuxOutput("break-pane", "-d", "-s", paneID)
	return err
}

func paneLocation(paneID string) (string, string, error) {
	if paneID == "" {
		return "", "", fmt.Errorf("missing pane")
	}
	out, err := tmuxOutput("display-message", "-p", "-t", paneID, "#{window_id}\t#{session_id}")
	if err != nil {
		return "", "", err
	}
	parts := strings.SplitN(strings.TrimSpace(out), "\t", 2)
	if len(parts) != 2 {
		return "", "", fmt.Errorf("unexpected pane location: %s", strings.TrimSpace(out))
	}
	return parts[0], parts[1], nil
}

func applyPaneSwap(sourceID string, targetID string) error {
	if sourceID == "" || targetID == "" {
		return fmt.Errorf("missing pane to swap")
	}
	_, err := tmuxOutput("swap-pane", "-d", "-s", sourceID, "-t", targetID)
	return err
}

func applyWindowSwap(sourceID string, targetID string) error {
	if sourceID == "" || targetID == "" {
		return fmt.Errorf("missing window to swap")
	}
	_, err := tmuxOutput("swap-window", "-d", "-s", sourceID, "-t", targetID)
	return err
}

func splitLines(s string) []string {
	s = strings.TrimRight(s, "\n")
	if s == "" {
		return nil
	}
	return strings.Split(s, "\n")
}

func parseSessionsOutput(out string) []Session {
	lines := splitLines(out)
	sessions := make([]Session, 0, len(lines))
	for _, line := range lines {
		parts := strings.SplitN(line, "\t", 2)
		if len(parts) != 2 {
			continue
		}
		sessions = append(sessions, Session{ID: parts[0], Name: parts[1]})
	}

	return sessions
}

func parseWindowsOutput(out string) []Window {
	lines := splitLines(out)
	windows := make([]Window, 0, len(lines))
	for _, line := range lines {
		parts := strings.SplitN(line, "\t", 4)
		if len(parts) != 4 {
			continue
		}
		indexNum := 0
		if parsed, err := strconv.Atoi(parts[2]); err == nil {
			indexNum = parsed
		}
		windows = append(windows, Window{
			ID:        parts[0],
			SessionID: parts[1],
			Index:     parts[2],
			IndexNum:  indexNum,
			Name:      parts[3],
		})
	}

	return windows
}

func parsePanesOutput(out string) []Pane {
	lines := splitLines(out)
	panes := make([]Pane, 0, len(lines))
	for _, line := range lines {
		parts := strings.SplitN(line, "\t", 7)
		if len(parts) != 7 {
			continue
		}
		indexNum := 0
		if parsed, err := strconv.Atoi(parts[3]); err == nil {
			indexNum = parsed
		}
		panes = append(panes, Pane{
			ID:        parts[0],
			WindowID:  parts[1],
			SessionID: parts[2],
			IndexNum:  indexNum,
			Path:      parts[4],
			Command:   parts[5],
			Title:     parts[6],
		})
	}

	return panes
}
