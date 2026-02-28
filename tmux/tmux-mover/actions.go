package main

import "fmt"

type choice struct {
	ID    string
	Label string
}

type ActionType string

const (
	ActionPaneMove   ActionType = "pane_move"
	ActionWindowMove ActionType = "window_move"
)

type StagedAction struct {
	Type     ActionType
	SourceID string
	TargetID string
	NewName  string
}

func buildWindowChoices(state TmuxState, excludeWindowID string) []choice {
	sessionByID := make(map[string]Session, len(state.Sessions))
	for _, s := range state.Sessions {
		sessionByID[s.ID] = s
	}
	choices := make([]choice, 0, len(state.Windows))
	for _, w := range state.Windows {
		if w.ID == excludeWindowID {
			continue
		}
		session := sessionByID[w.SessionID]
		label := fmt.Sprintf("%s %s:%s", session.Name, w.Index, w.Name)
		choices = append(choices, choice{ID: w.ID, Label: label})
	}
	return choices
}

func buildSessionChoices(state TmuxState, excludeSessionID string) []choice {
	choices := make([]choice, 0, len(state.Sessions))
	for _, s := range state.Sessions {
		if s.ID == excludeSessionID {
			continue
		}
		choices = append(choices, choice{ID: s.ID, Label: s.Name})
	}
	return choices
}

func movePanesToWindow(m model, paneIDs []string, windowID string) (int, int, string, string, error) {
	moved := 0
	skipped := 0
	newSelfWindowID := ""
	newSelfSessionID := ""
	for _, paneID := range paneIDs {
		if windowIDForPane(m.state, paneID) == windowID {
			skipped++
			continue
		}
		action := StagedAction{Type: ActionPaneMove, SourceID: paneID, TargetID: windowID}
		if err := applyPaneMove(action); err != nil {
			return moved, skipped, newSelfWindowID, newSelfSessionID, err
		}
		moved++
		if paneID == m.selfPaneID {
			newSelfWindowID = windowID
			newSelfSessionID = sessionIDForWindow(m.state, windowID)
		}
	}
	return moved, skipped, newSelfWindowID, newSelfSessionID, nil
}

func moveWindowsToSession(m model, windowIDs []string, sessionID string) (int, int, string, error) {
	moved := 0
	skipped := 0
	newSelfSessionID := ""
	for _, windowID := range windowIDs {
		if sessionIDForWindow(m.state, windowID) == sessionID {
			skipped++
			continue
		}
		action := StagedAction{Type: ActionWindowMove, SourceID: windowID, TargetID: sessionID}
		if err := applyWindowMove(action); err != nil {
			return moved, skipped, newSelfSessionID, err
		}
		moved++
		if windowID == m.selfWindowID {
			newSelfSessionID = sessionID
		}
	}
	return moved, skipped, newSelfSessionID, nil
}

func refocusSelf(paneID string, sessionID string, windowID string, clientID string) error {
	if paneID == "" {
		return nil
	}
	if sessionID != "" {
		if clientID != "" {
			_, _ = tmuxOutput("switch-client", "-c", clientID, "-t", sessionID)
		} else {
			_, _ = tmuxOutput("switch-client", "-t", sessionID)
		}
	}
	if windowID != "" {
		_, _ = tmuxOutput("select-window", "-t", windowID)
	}
	_, err := tmuxOutput("select-pane", "-t", paneID)
	return err
}

func refocusPane(m model, paneID string) error {
	if paneID == "" {
		return nil
	}
	sessionID := sessionIDForPane(m.state, paneID)
	windowID := windowIDForPane(m.state, paneID)
	return refocusSelf(paneID, sessionID, windowID, m.selfClientID)
}
