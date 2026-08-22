# Launcher Plan

This document is the decision point before adding more launcher actions.
Omarchy is a reference for category coverage and interaction patterns, not a
source of commands to copy directly.

## Rules

- Do not add an action unless the tool, behavior, and failure mode are known.
- Destructive or session-changing actions need confirmation before execution.
- A row in `launcher/.config/launcher/actions.json` means "selected and wired",
  not "interesting idea".
- Prefer a provider when the data is dynamic; prefer static JSON only for
  deliberate personal/system actions.
- Verify each category in the VM before committing it as implemented.

## Item Contract

Launcher items should keep the same UI-neutral shape:

```json
{
  "id": "kind:stable-id",
  "kind": "app | window | tab | tool | setting | system | script | state",
  "icon": "icon-name",
  "title": "Visible title",
  "subtitle": "Visible context",
  "keywords": ["search", "terms"],
  "actions": [
    {
      "id": "run",
      "title": "Action title",
      "command": "shell command",
      "danger": "none | session | destructive",
      "confirm": false
    }
  ]
}
```

`danger` and `confirm` are not implemented in the UI yet. They are part of the
target contract so lock/logout/reboot/shutdown style actions do not become
silent direct commands.

## Modes

| Mode | Purpose | Current status |
| --- | --- | --- |
| `--all` | General palette. Should stay fast and useful; do not blindly include every slow provider. | Implemented, needs curation |
| `--apps` | Desktop applications. | Implemented via `.desktop` scan; candidate to move into Quickshell `DesktopEntries` later |
| `--actions` | Static deliberate actions from `actions.json`. | Implemented |
| `--windows` | Live Hyprland windows. | Implemented |
| `--states` | Existing state-switcher rows. | Implemented if state-switcher is present |
| `--tabs` | Browser tabs. | Provider hook implemented; collector not chosen |

## Omarchy Reference Inventory

| Area | Omarchy reference | Our status | Candidate tools | Decision needed |
| --- | --- | --- | --- | --- |
| Apps | `apps` provider, `AppLibrary.qml`, `DesktopEntries` | Implemented minimally | current `.desktop` parser; Quickshell `DesktopEntries`; `gtk-launch`/`uwsm-app` | Whether app discovery should move into Quickshell service for icons/speed |
| Windows | Hyprland IPC and menu/panel patterns | Implemented | `hyprctl clients -j`, Lua dispatcher helpers | Whether window actions need more operations: move workspace, pin, fullscreen |
| Browser tabs | Not a root Omarchy menu item; our own requirement | Hook only | Firefox profile/session parser; browser extension/native messaging; Chrome remote debugging | Pick browser(s) and collection mechanism |
| Calculator | Omarchy keybind launches `omacalc` | Basic terminal row | `qalc`, custom Quickshell inline result, separate floating terminal | Whether calculator should be inline query provider or standalone |
| Lock | `system.lock`, `SUPER+CTRL+L`, `omarchy-system-lock` | Candidate only | `hyprlock`; possibly with `hypridle` for idle lock | Choose locker, theme, manual lock command, idle policy |
| Idle lock / stay awake | `trigger.toggle.idle-lock`, `SUPER+CTRL+I` | Candidate only | `hypridle`, systemd inhibitor, custom toggle state | Decide idle behavior before adding toggles |
| Logout | `system.logout` | Candidate only | Hyprland dispatch exit, login manager session end, Quickshell confirmation | Define expected logout behavior and confirmation |
| Suspend / hibernate | `system.suspend`, `system.hibernate` | Candidate only | `systemctl suspend`, `systemctl hibernate`, inhibitors | Hardware support check and confirmation |
| Reboot / shutdown | `system.reboot`, `system.shutdown` | Candidate only | `systemctl reboot`, `systemctl poweroff`, custom confirmation UI | Confirmation UI required before adding |
| Bluetooth | Bluetooth panel and restart action | Static toggle row implemented, rough | `bluetoothctl`, Quickshell Bluetooth panel, `rfkill`, `systemctl restart bluetooth` | Decide whether this is a simple action or panel with device selection |
| Network | Network setup, QR, panel | Candidate only | NetworkManager, `nmcli`, `nmtui`, Quickshell network panel | Confirm NetworkManager usage and desired UI depth |
| Audio | Audio panel and restart action | Candidate only | `wpctl`, `pavucontrol`, Quickshell audio panel | Decide between quick actions and panel |
| Display / brightness | Monitor panel, hardware toggles | Candidate only | `hyprctl monitors`, `brightnessctl`, Quickshell monitor panel | Identify real hardware requirements |
| Capture / OCR / QR / color | `trigger.capture.*` | Candidate only | grim/slurp/swappy, gpu-screen-recorder, tesseract, hyprpicker, zbar | Decide which capture workflows matter |
| Notifications | Notification dismiss/history/silence binds | Candidate only | Quickshell notification service, `mako`/`swaync` if chosen | Pick notification stack first |
| Style/theme/background | `style.*` menus | Candidate only | existing dotfiles theme source, Quickshell theme service | Avoid hand-maintained one-off themes |
| Config editors | `setup.config.*` | Candidate only | `$EDITOR`, Ghostty + nvim, direct file actions | Decide if launcher should expose config files |
| Defaults | Default browser/editor/terminal/agent | Candidate only | `xdg-settings`, alternatives, repo-specific scripts | Probably later; not useful until real host |
| Install/remove/update | Large Omarchy install/remove/update menus | Mostly out of scope | Nix/Home Manager rebuild commands | Decide whether launcher should ever install/remove packages |
| Hardware toggles | touchpad, touchscreen, hybrid GPU, laptop display | Candidate only | hardware-specific scripts | Only after real hardware pass |
| Reminders/share/transcode | Omarchy trigger workflows | Candidate only | TBD | Not in first pass |
| State switcher | Our existing state-switcher script | Implemented | `state-switcher.5m` | Decide richer UI later |
| Custom scripts | User-specific helper scripts | Partially implemented | `helper_scripts/bin/*`, static actions | Add one by one after tool/behavior review |

## Current Static Actions

These are the only actions currently allowed in `actions.json`:

| Action | Kind | Tool | Notes |
| --- | --- | --- | --- |
| Toggle Power Profile | `setting` | `helpers/low-power-mode-toggle.sh`, `powerprofilesctl` | Already ported and verified earlier |
| Toggle Bluetooth | `setting` | `bt-toggle`, `bluetoothctl` | Needs a better decision: simple toggle vs panel |
| Calculator | `tool` | `qalc` in Ghostty | Temporary; inline calculator is a separate decision |
| Restart Quickshell | `script` | `pkill quickshell; quickshell ...` | Useful while developing shell |
| Reload Hyprland | `script` | `hyprctl reload` | Useful while developing WM config |

## Category Implementation Checklist

Before moving a row from candidate to implemented:

1. Pick the tool.
2. Add the package if needed.
3. Define the command/provider.
4. Define failure behavior.
5. Define confirmation behavior if `danger != none`.
6. Test command directly.
7. Test launcher row.
8. Test VM behavior.
9. Commit only that category.

## Proposed Sequence

1. Polish current launcher UX: popup geometry, search behavior, mode naming.
2. Apps provider: decide whether to keep script parser or use Quickshell
   `DesktopEntries`.
3. Calculator: decide terminal-only vs inline query result.
4. Lock: choose `hyprlock` or another locker, then wire manual lock.
5. Power/session menu: add confirmation UI before logout/suspend/reboot/shutdown.
6. Bluetooth: decide action vs panel and device-level operations.
7. Browser tabs: choose Firefox/Chrome collection strategy.
8. Network/audio/display panels.

