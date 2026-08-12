package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
)

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--agents-status":
			os.Exit(runStatusCLI(false))
		case "--agents-json":
			os.Exit(runStatusCLI(true))
		}
	}

	p := tea.NewProgram(model{keys: defaultKeymap()}, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
