package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type State struct {
	Title                  string `json:"title"`
	Icon                   string `json:"icon"`
	Paths                  string `json:"paths"`
	OnEnabled              string `json:"on_enabled"`
	OnDisabled             string `json:"on_disabled"`
	AlwaysSourcedIfEnabled bool   `json:"always_sourced_if_enabled"`
	Disabled               bool   `json:"disabled"`
}

func main() {
	args := os.Args[1:]
	var arg1, arg2, arg3 string
	if len(args) > 0 {
		arg1 = args[0]
	}
	if len(args) > 1 {
		arg2 = args[1]
	}
	if len(args) > 2 {
		arg3 = args[2]
	}

	style := "size=13"

	homeDir, err := os.UserHomeDir()
	if err != nil {
		fmt.Println("Error getting home directory:", err)
		return
	}

	configFile := filepath.Join(homeDir, "dotfiles/bitbar/Documents/bitbar_plugins/tmp/states.json")
	statesData, err := readConfigFile(configFile)
	if err != nil {
		fmt.Println("Error reading config file:", err)
		return
	}

	var enabledStates []State
	for _, state := range statesData {
		if !state.Disabled {
			enabledStates = append(enabledStates, state)
		}
	}

	titles := []string{}
	icons := make(map[string]string)
	paths := make(map[string]string)
	onEnabledCommands := make(map[string]string)
	onDisabledCommands := make(map[string]string)
	alwaysSourcedIfEnabled := make(map[string]bool)

	for _, state := range enabledStates {
		titles = append(titles, state.Title)
		icons[state.Title] = state.Icon
		paths[state.Title] = substituteEnvVars(state.Paths)
		onEnabledCommands[state.Title] = state.OnEnabled
		onDisabledCommands[state.Title] = state.OnDisabled
		alwaysSourcedIfEnabled[state.Title] = state.AlwaysSourcedIfEnabled
	}

	stateIconsFilePath := filepath.Join(homeDir, "Documents/bitbar_plugins/tmp/enabled_state_icons.txt")

	switch arg1 {
	case "":
		generateBitbarMenu(titles, icons, style)
	case "enabled-states":
		var enabledStatesList []string
		for _, title := range titles {
			if fileExists(getFilePath(title)) {
				enabledStatesList = append(enabledStatesList, title)
			}
		}
		fmt.Println(strings.Join(enabledStatesList, " "))
	case "is-state-enabled":
		if fileExists(getFilePath(arg2)) {
			os.Exit(0)
		} else {
			os.Exit(1)
		}
	case "always-sourced-if-enabled":
		if fileExists(getFilePath(arg2)) && alwaysSourcedIfEnabled[arg2] {
			os.Exit(0)
		} else {
			os.Exit(1)
		}
	case "enabled-states-paths":
		var pathsList []string
		for _, title := range titles {
			if fileExists(getFilePath(title)) {
				pathsList = append(pathsList, paths[title])
			}
		}
		fmt.Println(strings.Join(pathsList, " "))
	case "state-paths":
		fmt.Println(paths[arg2])
	case "states":
		fmt.Println(strings.Join(titles, " "))
	case "states-with-marks":
		maxLen := 0
		for _, title := range titles {
			if len(title) > maxLen {
				maxLen = len(title)
			}
		}
		for _, title := range titles {
			mark := "✅"
			if !fileExists(getFilePath(title)) {
				mark = "❌"
			}
			fmt.Printf("%-*s %s\n", maxLen, title, mark)
		}
	case "toggle":
		toggleState(arg2, arg3, titles, icons, onEnabledCommands, onDisabledCommands, stateIconsFilePath)
	case "run_hook":
		runHook(arg2, arg3, onEnabledCommands, onDisabledCommands)
	default:
		fmt.Println("Invalid argument")
	}
}

func readConfigFile(filePath string) ([]State, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}
	var states []State
	err = json.Unmarshal(data, &states)
	if err != nil {
		return nil, err
	}
	return states, nil
}

func substituteEnvVars(path string) string {
	return os.ExpandEnv(path)
}

func getFilePath(state string) string {
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, "Documents/bitbar_plugins/tmp", state)
}

func fileExists(filePath string) bool {
	_, err := os.Stat(filePath)
	return !os.IsNotExist(err)
}

func generateBitbarMenu(titles []string, icons map[string]string, style string) {
	fmt.Println(" | font='Symbols Nerd Font' size=18")
	fmt.Println("---")
	for _, title := range titles {
		filePath := getFilePath(title)
		mark := "✅"
		if !fileExists(filePath) {
			mark = "❌"
		}
		icon := icons[title]
		var displayTitle string
		if icon == "" {
			displayTitle = fmt.Sprintf("___%s", title)
		} else {
			displayTitle = fmt.Sprintf("%s %s", icon, title)
		}
		fmt.Printf("%s\t%s | bash=%s param1=toggle param2=%s terminal=false %s\n",
			displayTitle, mark, os.Args[0], title, style)
		fmt.Printf("--Run on_enabled | bash=%s param1=run_hook param2=on_enabled param3=%s refresh=false terminal=false %s\n",
			os.Args[0], title, style)
		fmt.Printf("--Run on_disabled | bash=%s param1=run_hook param2=on_disabled param3=%s refresh=false terminal=false %s\n",
			os.Args[0], title, style)
		alternateContent := fmt.Sprintf("%s\t%s", displayTitle, mark)
		fmt.Printf("%s | bash=%s param1=toggle param2=%s param3=ignore-event alternate=true refresh=true terminal=false %s\n",
			alternateContent, os.Args[0], title, style)
	}
	fmt.Println("Refresh | refresh=true " + style)
}

func toggleState(arg2, arg3 string, titles []string, icons map[string]string, onEnabledCommands, onDisabledCommands map[string]string, stateIconsFilePath string) {
	filePath := getFilePath(arg2)
	if contains(titles, arg2) {
		var command string
		if fileExists(filePath) {
			os.Remove(filePath)
			command = onDisabledCommands[arg2]
		} else {
			f, err := os.Create(filePath)
			if err != nil {
				fmt.Println("Error creating file:", err)
				return
			}
			f.Close()
			command = onEnabledCommands[arg2]
		}
		var enabledIcons []string
		for _, title := range titles {
			if fileExists(getFilePath(title)) && len(icons[title]) > 0 {
				enabledIcons = append(enabledIcons, icons[title])
			}
		}
		err := os.WriteFile(stateIconsFilePath, []byte(strings.Join(enabledIcons, " ")), 0644)
		if err != nil {
			fmt.Println("Error writing state icons file:", err)
		}
		if command != "" && arg3 != "ignore-event" {
			runOnCommandHook(arg2, command)
		}
		exec.Command("open", "-g", "bitbar://refreshPlugin?name=*").Run()
	}
}

func runHook(arg2, arg3 string, onEnabledCommands, onDisabledCommands map[string]string) {
	var command string
	if arg2 == "on_enabled" {
		command = onEnabledCommands[arg3]
	} else if arg2 == "on_disabled" {
		command = onDisabledCommands[arg3]
	}
	if command != "" {
		runOnCommandHook(arg3, command)
	}
}

func runOnCommandHook(customState, command string) {
	cmdStr := fmt.Sprintf(`export PATH="$HOME/.nix-profile/bin:$PATH"; __custom_state=%s;  source ~/.zshrc; %s;`, customState, command)
	cmd := exec.Command(os.Getenv("HOME") + "/.nix-profile/bin/zsh", "-c", cmdStr)
	cmd.Stdout = nil
	cmd.Stderr = nil
	cmd.Start()
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}
