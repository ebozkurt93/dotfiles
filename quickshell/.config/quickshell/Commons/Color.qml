pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Base palette (Catppuccin Mocha) and shared tokens. Per-surface blocks
    // below derive from these so most of the theme lives in one place; a
    // surface only needs its own value when it genuinely differs.
    readonly property color background: "#11111b"
    readonly property color foreground: "#cdd6f4"
    readonly property color muted: "#a6adc8"
    readonly property color accent: "#89b4fa"
    readonly property color danger: "#f38ba8"
    readonly property color dangerText: "#f5c2e7"

    readonly property color transparent: "transparent"

    readonly property QtObject bar: QtObject {
        property color background: "#1e1e2e"
        property color text: root.foreground
        property color workspaceActive: root.accent
        property color workspaceInactive: "#313244"
    }

    readonly property QtObject lock: QtObject {
        property color background: root.background
        property color text: root.foreground
        property color textError: root.danger
        property color placeholder: root.muted
        property color border: "#45475a"
        property color borderError: root.danger
        property color passwordBoxBackground: "#181825"
        property color selection: root.accent
        property color textOnAccent: root.background
        property color powerButtonBackground: "#313244"
        property color powerButtonBorder: "#45475a"
        property color powerButtonHover: "#45475a"
        property color dangerButtonBackground: "#3a2432"
        property color dangerButtonBorder: root.danger
        property color dangerButtonText: root.dangerText
    }

    readonly property QtObject launcher: QtObject {
        property color scrim: "#000000"
        property color cardBackground: "#181825"
        property color cardBorder: "#45475a"
        property color inputBackground: root.background
        property color inputBorder: "#313244"
        property color text: root.foreground
        property color textMuted: root.muted
        property color selection: root.accent
        property color selectionBackground: "#313244"
        property color selectionBorder: root.accent
        property color textOnAccent: root.background
    }
}
