package main

import tea "github.com/charmbracelet/bubbletea"

func keyMatches(msg tea.KeyMsg, keys []string) bool {
	if len(keys) == 0 {
		return false
	}
	value := msg.String()
	for _, key := range keys {
		if value == key {
			return true
		}
		if matchesKeyType(msg, key) {
			return true
		}
	}
	return false
}

func matchesKeyType(msg tea.KeyMsg, key string) bool {
	switch key {
	case "up":
		return msg.Type == tea.KeyUp
	case "down":
		return msg.Type == tea.KeyDown
	case "left":
		return msg.Type == tea.KeyLeft
	case "right":
		return msg.Type == tea.KeyRight
	case "enter":
		return msg.Type == tea.KeyEnter
	case "backspace":
		return msg.Type == tea.KeyBackspace
	case "esc":
		return msg.Type == tea.KeyEsc
	default:
		return false
	}
}

func normalizeKeymap(keys Keymap) Keymap {
	if joinKeys(keys.MoveDown) == "" &&
		joinKeys(keys.MoveUp) == "" &&
		joinKeys(keys.MovePane) == "" &&
		joinKeys(keys.MoveWindow) == "" &&
		joinKeys(keys.Cancel) == "" &&
		joinKeys(keys.Quit) == "" {
		return defaultKeymap()
	}
	return keys
}
