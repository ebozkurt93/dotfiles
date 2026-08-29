local hostname = os.getenv("HOSTNAME") or ""
if hostname == "" then
    local handle = io.popen("hostname 2>/dev/null")
    if handle then
        hostname = handle:read("*l") or ""
        handle:close()
    end
end

local lowSpecDesktop = hostname == "utm-aarch64" or os.getenv("DOTFILES_LOW_SPEC_DESKTOP") == "1"

-- Defaults to 1.0 (no scaling); override per-session with DOTFILES_DISPLAY_SCALE while tuning real hardware.
local displayScale = tonumber(os.getenv("DOTFILES_DISPLAY_SCALE")) or 1.0

hl.monitor({
    output = "",
    mode = lowSpecDesktop and "1280x800@60" or "preferred",
    position = "auto",
    scale = displayScale,
})

hl.on("hyprland.start", function()
    -- Quickshell is launched directly by Hyprland, not a login shell, so source .personal.zshrc first so its Process calls inherit vars like HEADSCALE_URL.
    hl.exec_cmd("zsh -c 'source \"$HOME/.personal.zshrc\" 2>/dev/null; exec quickshell'")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("mako")
    hl.exec_cmd(os.getenv("HOME") .. "/bin/desktop notification-times-watcher")
end)

hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Adwaita")

-- Off by default; toggle via `desktop notifications-privacy`.
do
    local f = io.open(os.getenv("HOME") .. "/.local/state/desktop/notifications-privacy", "r")
    if f then
        f:close()
        hl.layer_rule({ match = { namespace = "notifications" }, no_screen_share = true })
    end
end

hl.config({
    ecosystem = {
        no_update_news = true,
    },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        -- Mirrors macOS's KeyRepeat=1/InitialKeyRepeat=10 (repeat_rate is Hz, repeat_delay is ms).
        repeat_rate = 60,
        repeat_delay = 150,
        -- libinput's -1.0..1.0 pointer-speed range (0 = neutral); untested on real hardware, a starting point to retune.
        sensitivity = 0.0,
        accel_profile = "adaptive",
        touchpad = {
            natural_scroll = false,
            scroll_factor = 1.0,
        },
    },

    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        layout = "scrolling",
        resize_on_border = true,
    },

    decoration = {
        rounding = 6,
        blur = {
            enabled = true,
            size = 8,
            passes = 1,
        },
    },

    animations = {
        enabled = true,
    },

    cursor = {
        -- UTM's virtio-gpu has hardware-cursor rendering bugs; force software cursor there only.
        no_hardware_cursors = lowSpecDesktop,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },

    scrolling = {
        fullscreen_on_one_column = true,
        column_width = 0.5,
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
        direction = "right",
    },
})

-- Overriding "global" is enough since every category without its own override inherits from it (speed is ~100ms units, lower = faster).
hl.animation({ leaf = "global", enabled = true, speed = 1.5, bezier = "default" })

local mainMod = "SUPER"
local home = os.getenv("HOME")

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("ghostty"), { description = "Open a new terminal" })
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Close window" })
-- Confirm/cancel picker instead of exiting directly -- too easy to fat-finger from SUPER+Q (close window).
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd(home .. "/bin/launcher --confirm-exit"), { description = "Exit Hyprland" })
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(home .. "/bin/launcher --all"), { description = "Open launcher" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }), { description = "Toggle fullscreen" })
hl.bind(mainMod .. " + CTRL + Q", hl.dsp.exec_cmd(home .. "/bin/desktop lock"), { description = "Lock screen" })
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd(home .. "/bin/launcher --windows"), { description = "Open window switcher" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(home .. "/bin/launcher --tabs"), { description = "Open browser tabs" })
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(home .. "/bin/launcher --bluetooth"), { description = "Open bluetooth devices" })
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd(home .. "/bin/desktop text-expander --toggle"), { description = "Toggle text expansion" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(home .. "/bin/desktop notifications-dnd toggle"), { description = "Toggle do-not-disturb" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("quickshell ipc call notificationHistory toggle"), { description = "Open notification history" })

hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.exec_cmd(home .. "/bin/desktop screenshot fullscreen"), { description = "Screenshot: fullscreen" })
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.exec_cmd(home .. "/bin/desktop screenshot region"), { description = "Screenshot: region" })
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("quickshell ipc call clipboard toggle"), { description = "Open clipboard history" })

-- Scrolling-layout focus: move focus between columns (h/l, left/right) and
-- within a column's stack (j/k, up/down). Auto-scrolls the tape into view.
for _, key in ipairs({ "h", "left" }) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.layout("focus l"), { description = "Focus column left" })
end
for _, key in ipairs({ "l", "right" }) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.layout("focus r"), { description = "Focus column right" })
end
for _, key in ipairs({ "k", "up" }) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.layout("focus u"), { description = "Focus up within column stack" })
end
for _, key in ipairs({ "j", "down" }) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.layout("focus d"), { description = "Focus down within column stack" })
end

-- Expels first so a stacked window swaps individually rather than dragging its whole stack; swap-window checks a neighbor exists first.
hl.bind(mainMod .. " + SHIFT + h",    hl.dsp.exec_cmd(home .. "/bin/desktop swap-window l"), { description = "Swap window with column left" })
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.exec_cmd(home .. "/bin/desktop swap-window l"), { description = "Swap window with column left" })
hl.bind(mainMod .. " + SHIFT + l",     hl.dsp.exec_cmd(home .. "/bin/desktop swap-window r"), { description = "Swap window with column right" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd(home .. "/bin/desktop swap-window r"), { description = "Swap window with column right" })

-- Stack with a neighboring column, or pop back out with "promote" (acts on the focused window, unlike "expel" which always evicts the column's last window).
hl.bind(mainMod .. " + SHIFT + j",    hl.dsp.exec_cmd(home .. "/bin/desktop stack-window"), { description = "Stack window with a neighboring column" })
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.exec_cmd(home .. "/bin/desktop stack-window"), { description = "Stack window with a neighboring column" })
hl.bind(mainMod .. " + SHIFT + k",  hl.dsp.layout("promote"), { description = "Pop window into its own column" })
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.layout("promote"), { description = "Pop window into its own column" })

-- Promote the focused window into a brand new dedicated column.
hl.bind(mainMod .. " + P", hl.dsp.layout("promote"), { description = "Promote window into a new column" })

-- Resize the focused column: CTRL+h/l shrink/grow width by 10%, CTRL+C
-- cycles through the explicit_column_widths presets (33/50/67/100%) -- the
-- "center at ~70% width" habit lands on the 0.667 preset.
hl.bind(mainMod .. " + CTRL + h",     hl.dsp.layout("colresize -0.1"), { description = "Shrink column width" })
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.layout("colresize -0.1"), { description = "Shrink column width" })
hl.bind(mainMod .. " + CTRL + l",     hl.dsp.layout("colresize +0.1"), { description = "Grow column width" })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.layout("colresize +0.1"), { description = "Grow column width" })
hl.bind(mainMod .. " + CTRL + C", hl.dsp.layout("colresize +conf"), { description = "Cycle column width preset" })

-- No native "rowresize" layout message exists (unlike "colresize"); rowresize builds one on the same absolute-size resize dispatcher.
hl.bind(mainMod .. " + CTRL + k",    hl.dsp.exec_cmd(home .. "/bin/desktop rowresize -0.1"), { description = "Shrink row height" })
hl.bind(mainMod .. " + CTRL + up",   hl.dsp.exec_cmd(home .. "/bin/desktop rowresize -0.1"), { description = "Shrink row height" })
hl.bind(mainMod .. " + CTRL + j",    hl.dsp.exec_cmd(home .. "/bin/desktop rowresize +0.1"), { description = "Grow row height" })
hl.bind(mainMod .. " + CTRL + down", hl.dsp.exec_cmd(home .. "/bin/desktop rowresize +0.1"), { description = "Grow row height" })

-- Raise-or-launch pinned apps: focus the most-recently-focused window of
-- the app if one exists (mirrors hammerspoon's launchOrFocus), else launch it.
hl.bind(mainMod .. " + ALT + k", hl.dsp.exec_cmd(home .. "/bin/desktop raise-or-launch com.mitchellh.ghostty ghostty"), { description = "Jump to (or launch) terminal" })
hl.bind(mainMod .. " + ALT + b", hl.dsp.exec_cmd(home .. "/bin/desktop raise-or-launch firefox-devedition firefox-devedition"), { description = "Jump to (or launch) Firefox" })
hl.bind(mainMod .. " + ALT + o", hl.dsp.exec_cmd(home .. "/bin/desktop raise-or-launch md.Obsidian obsidian"), { description = "Jump to (or launch) Obsidian" })
hl.bind(mainMod .. " + ALT + f", hl.dsp.exec_cmd(home .. "/bin/desktop raise-or-launch FreeCAD freecad"), { description = "Jump to (or launch) FreeCAD" })
hl.bind(mainMod .. " + ALT + c", hl.dsp.exec_cmd(home .. "/bin/desktop raise-or-launch org.gnome.Calendar gnome-calendar"), { description = "Jump to (or launch) Calendar" })

-- Move focus to / move the focused window to a neighboring monitor,
-- regardless of whether monitors are arranged side-by-side or stacked.
hl.bind(mainMod .. " + ALT + h",     hl.dsp.focus({ monitor = "l" }), { description = "Focus monitor left" })
hl.bind(mainMod .. " + ALT + left",  hl.dsp.focus({ monitor = "l" }), { description = "Focus monitor left" })
hl.bind(mainMod .. " + ALT + l",     hl.dsp.focus({ monitor = "r" }), { description = "Focus monitor right" })
hl.bind(mainMod .. " + ALT + right", hl.dsp.focus({ monitor = "r" }), { description = "Focus monitor right" })
hl.bind(mainMod .. " + ALT + up",    hl.dsp.focus({ monitor = "u" }), { description = "Focus monitor up" })
hl.bind(mainMod .. " + ALT + j",     hl.dsp.focus({ monitor = "d" }), { description = "Focus monitor down" })
hl.bind(mainMod .. " + ALT + down",  hl.dsp.focus({ monitor = "d" }), { description = "Focus monitor down" })
hl.bind(mainMod .. " + ALT + SHIFT + h",     hl.dsp.window.move({ monitor = "l" }), { description = "Move window to monitor left" })
hl.bind(mainMod .. " + ALT + SHIFT + left",  hl.dsp.window.move({ monitor = "l" }), { description = "Move window to monitor left" })
hl.bind(mainMod .. " + ALT + SHIFT + l",     hl.dsp.window.move({ monitor = "r" }), { description = "Move window to monitor right" })
hl.bind(mainMod .. " + ALT + SHIFT + right", hl.dsp.window.move({ monitor = "r" }), { description = "Move window to monitor right" })
hl.bind(mainMod .. " + ALT + SHIFT + k",     hl.dsp.window.move({ monitor = "u" }), { description = "Move window to monitor up" })
hl.bind(mainMod .. " + ALT + SHIFT + up",    hl.dsp.window.move({ monitor = "u" }), { description = "Move window to monitor up" })
hl.bind(mainMod .. " + ALT + SHIFT + j",     hl.dsp.window.move({ monitor = "d" }), { description = "Move window to monitor down" })
hl.bind(mainMod .. " + ALT + SHIFT + down",  hl.dsp.window.move({ monitor = "d" }), { description = "Move window to monitor down" })

-- Workspaces are global/shared across monitors, not pinned per-screen; this explicitly places one on a specific screen.
hl.bind(mainMod .. " + CTRL + ALT + h",     hl.dsp.workspace.move({ monitor = "l" }), { description = "Move workspace to monitor left" })
hl.bind(mainMod .. " + CTRL + ALT + left",  hl.dsp.workspace.move({ monitor = "l" }), { description = "Move workspace to monitor left" })
hl.bind(mainMod .. " + CTRL + ALT + l",     hl.dsp.workspace.move({ monitor = "r" }), { description = "Move workspace to monitor right" })
hl.bind(mainMod .. " + CTRL + ALT + right", hl.dsp.workspace.move({ monitor = "r" }), { description = "Move workspace to monitor right" })
hl.bind(mainMod .. " + CTRL + ALT + k",     hl.dsp.workspace.move({ monitor = "u" }), { description = "Move workspace to monitor up" })
hl.bind(mainMod .. " + CTRL + ALT + up",    hl.dsp.workspace.move({ monitor = "u" }), { description = "Move workspace to monitor up" })
hl.bind(mainMod .. " + CTRL + ALT + j",     hl.dsp.workspace.move({ monitor = "d" }), { description = "Move workspace to monitor down" })
hl.bind(mainMod .. " + CTRL + ALT + down",  hl.dsp.workspace.move({ monitor = "d" }), { description = "Move workspace to monitor down" })

for i = 1, 10 do
    local key = i == 10 and "0" or tostring(i)
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "Switch to workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace " .. i })
end

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Drag floating window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize floating window" })

hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd(home .. "/bin/launcher --keybinds"), { description = "Show keybindings" })

dofile(home .. "/.config/hypr/media-keys.lua")
