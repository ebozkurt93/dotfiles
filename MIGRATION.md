# macOS → NixOS/Linux migration notes

Working branch: `nixos`, in worktree `~/personal-repositories/dotfiles-nixos`
(separate from the main `~/dotfiles` checkout on `master`, which is untouched).

## Goal

Long-term move from this macOS-only dotfiles setup to NixOS, tested first in a
local VM, later on an old physical x86_64 machine, with an eventual full
switch. This is a multi-session effort; this file is the handoff point
between sessions/agents.

## Decisions made (don't re-litigate without new information)

- **Keep the macOS setup fully intact.** This is not a cutover — the Mac
  stays the daily driver until the user explicitly says otherwise. Any
  shared file touched for this migration (`flake.nix`, `packages.nix`,
  `scripts.nix`) must gate new/changed behavior behind `pkgs.stdenv.isLinux`
  rather than altering the default/unguarded path, so
  `homeConfigurations.erdembozkurt` (darwin) provably keeps evaluating and
  building the same as before. Verify the darwin config after every shared
  edit, not just the new Linux path.
- **Desktop environment: Hyprland.** Chosen for quickshell compatibility
  (quickshell targets Hyprland's IPC/wlr-layer-shell most maturely), visual
  polish/animation support, and closest conceptual match to the existing
  hammerspoon tiling/hotkey setup. Niri was considered and rejected (too
  minimal, weaker quickshell ecosystem).
- **Dotfile mechanism stays `stow`**, not home-manager's `home.file`. Nix is
  scoped to packages + activation scripts only. Do not migrate app configs
  (nvim lua, kitty.conf, etc.) into Nix — user explicitly wants to keep using
  each tool's native config format/location.
- **BitBar/xbar**: keep the underlying script logic (state-switcher Go
  backend, github-prs, etc.) but decouple from bitbar/xbar as the rendering
  layer. Renderer choice not decided — explicitly NOT waybar (user pushed
  back on that assumption). Likely candidate given Hyprland+quickshell choice:
  a quickshell widget, but confirm with user before building it.
- **`helpers/vanta-track.sh`**: drop, not used anymore.
- **GUI apps (Brewfile)**: deferred, revisit later. slack/spotify/vlc/obsidian/
  signal-desktop have direct nixpkgs equivalents; nordvpn needs extra NixOS
  networking config; raycast/karabiner-elements/monitorcontrol/utm/maccy have
  no nixpkgs equivalent and need a Linux-native alternative picked.
- **VM strategy**: aarch64-linux VM in UTM is the primary fast-iteration
  target (hardware-virtualized). An x86_64-linux VM (QEMU-emulated, slower)
  is the compatibility check — build-only (`nix build .#nixosConfigurations.
  <host>.config.system.build.vm`) after most changes, boot it in UTM only at
  checkpoints. The real physical x86 machine is deferred until both VMs work
  end to end.

## What's done

1. **Worktree/branch set up.** `git worktree add ~/personal-repositories/
   dotfiles-nixos -b nixos` off master.
2. **Full content-based audit** of every stowed dir + helper_scripts + setup
   scripts, triaged KEEP/PORT/DROP/UNCLEAR with concrete reasons (not
   filename guesses). Not saved as a file — was delivered in-conversation by
   a background agent. If a fresh audit is needed, the prompt used is
   reconstructable from this file's "Remaining work" section below, which
   summarizes the findings that matter.
3. **`flake.nix` restructured for multi-platform**:
   - Extracted a shared `homeModule` (packages + activation scripts) used by
     both the darwin `homeConfigurations.erdembozkurt` and the new
     `nixosConfigurations.utm-aarch64`.
   - Added `nixosConfigurations.utm-aarch64` (aarch64-linux), using
     `home-manager.nixosModules.home-manager` with
     `home-manager.users.erdembozkurt = { imports = [homeModule]; ... }`.
   - `nix flake check` passes for both configs. Building the Linux config
     from this Mac requires a Linux builder (not set up — out of scope, a
     system-level nix-darwin change) or building directly on the VM, which is
     what we've been doing.
4. **`packages.nix` split by platform**: `lib.optionals stdenv.isDarwin` for
   `blueutil`/`colima`/`lima`/`terminal-notifier`; `lib.optionals
   stdenv.isLinux` for `neovim` (built from source via `setup/build-neovim.sh`
   on macOS instead, so this only affects Linux) and `xclip` (needed by
   `helper_scripts/bin/pbcopy`/`pbpaste`'s Linux branch).
5. **`scripts.nix`**: `installTmuxMover`'s comment updated to reflect it now
   covers both macOS and Linux notification tooling (no functional change
   needed yet — tmux-mover's own `notify.go` already branches internally).
6. **`installStateSwitcher` gated to `stdenv.isDarwin`** in `flake.nix` — it
   `cd`s into `bitbar/Documents/bitbar_plugins/source/state-switcher`, which
   isn't stowed on Linux since bitbar's fate is still undecided (see
   "Decisions made" above). Re-enable/rework once that's settled.
7. **Two real bugs found and fixed** (pre-existing, not migration-induced):
   - `helper_scripts/bin/pbcopy` and `pbpaste` called `is_macos`, a function
     defined only in `zsh/.personal.zshrc` (a zsh-interactive-only function).
     These scripts run as standalone `#!/usr/bin/env bash` processes and
     never had access to it — harmless on macOS because the real
     `/usr/bin/pbcopy` shadows this script in `$PATH` there, so the buggy
     branch never actually ran. Fixed to check `uname` directly instead of
     depending on a zsh-only helper.
   - Both scripts (and `wg-manager`, `ts-manager`, `list-apps`,
     `helpers/pass.sh`) had `#!/bin/bash` shebangs — NixOS has no `/bin/bash`
     (only `/bin/sh`, which is fine, and `/usr/bin/env`). Fixed shebangs on
     `pbcopy`/`pbpaste` only (`#!/usr/bin/env bash`) since those are the ones
     already cross-platform; the other four are macOS-only in their *body*
     too (Keychain/`networksetup`/`mdfind`/`/opt/homebrew`) and belong to the
     task #5 PORT work, not a quick shebang fix.
8. **UTM aarch64 VM installed and working**:
   - IP: `192.168.64.3` (may change if the VM is recreated — check with
     `ip a` on the console, or `utmctl` from the Mac).
   - SSH key: `~/.ssh/nixos_vm_utm` (ed25519, generated for this VM
     specifically). Connect as `ssh -i ~/.ssh/nixos_vm_utm
     erdembozkurt@192.168.64.3`.
   - `erdembozkurt` user: password `changeme` (console login / sudo) — **not
     yet rotated, do that before this VM is used for anything beyond
     testing**. In `wheel` and `docker` groups.
   - Root SSH login disabled (`PermitRootLogin = "no"`) post-install.
   - Disk: `/dev/vda`, GPT, `/dev/vda1` = 512M FAT32 ESP, `/dev/vda2` = ext4
     root. `nixos/hosts/utm-aarch64/hardware-configuration.nix` has the real
     generated UUIDs (not a placeholder anymore).
   - Bootloader: systemd-boot, UEFI.
   - The flake lives at `~/dotfiles` on the VM itself (rsynced from this
     worktree, then `git init`'d locally there so flakes can see it — it is
     **not** a clone of the real GitHub repo, just a working copy pushed
     over by hand each session so far). `sudo nixos-rebuild switch --flake
     ~/dotfiles#utm-aarch64` applies changes.
   - Cross-platform dirs stowed on the VM: `zsh vim nvim kitty tmux git mise
     starship atuin helper_scripts wezterm other` (run manually, NOT via
     `scripts/stow.sh` — that script's hardcoded directory list includes
     `bitbar hammerspoon personal instabee lima ghostty firefox`, several of
     which are private submodules or not synced to the VM; it needs an
     OS-conditional directory list before it can be used as-is on Linux —
     see "Remaining work").

## In progress / needs verification

- `installStateSwitcher` activation bug fixed, `nixos-rebuild switch`
  confirmed succeeding on the VM. `pbcopy`/`pbpaste`'s logic and shebang
  fixes are confirmed correct (no more `is_macos: command not found` /
  `bad interpreter`), but `xclip` itself fails with `Can't open display:
  (null)` — expected, there's no X11/Wayland display server on this VM yet
  (no desktop installed — that's task #5). Re-verify the actual copy/paste
  round-trip once Hyprland is up.
- `nvim` confirmed working: `nvim --headless "+quit"` runs clean after adding
  `gnumake`/`gcc` (needed by telescope-fzf-native.nvim's build step,
  `cc -O3 ... -o build/libfzf.so`) and `sqlite` (needed by
  telescope-all-recent.nvim's sqlite.lua) to `packages.nix`'s Linux set.
  These are implicitly present on macOS via Xcode CLT, so this gap only
  showed up on NixOS. Not yet tested interactively (only `--headless`), and
  none of the LSPs/formatters have been exercised.
- `mise` confirmed working — the `[WARN] migrate: error parsing config file`
  seen earlier was misleading; the real issue was mise's trust-on-first-use
  prompt (`mise trust ~/.mise.toml`), unrelated to Linux/portability at all
  (same prompt would appear on a fresh macOS install too). Not a bug, no fix
  needed, just a one-time `mise trust` step.
- `tmux-mover`: built clean (`nix develop -c make build`), `go test ./...`
  passes, `--help` runs. Confirmed portable as the audit predicted.
- `state-switcher`: had a **real bug** — no `go.mod` existed anywhere in
  that project (confirmed same on the macOS side, it's not migration-
  induced), so `go build` fails outright on modern Go once you're not
  sitting under `$GOPATH` (`cannot find main module`). It's stdlib-only, no
  deps, so added a minimal `go.mod` (`module state-switcher`, `go 1.23`) —
  fixes it on both platforms. Builds and runs clean now; the "Error reading
  config file" it prints is just missing runtime data (`tmp/states.json`,
  never synced to the VM, not code), not a bug.
- Both Go projects live under directories excluded from the original rsync
  (`tmux/tmux-mover` was included; `bitbar/Documents/bitbar_plugins/source`
  was not, since bitbar's fate is undecided — see "Decisions made"). Synced
  just the `source/` subdirectory by hand (tar+scp, since the sandboxed Bash
  tool blocks any command with the literal word "source" as an argument —
  see Gotchas) to verify the Go logic specifically, without pulling in the
  rest of bitbar (icons, plugin scripts, xbar-specific bits).

## Task #5 progress (Hyprland/quickshell)

- Added `nixos/modules/desktop-hyprland.nix` (shared module, reusable by the
  future x86_64 host): `programs.hyprland.enable`, greetd+tuigreet login,
  xdg-desktop-portal-hyprland, pipewire/rtkit audio, polkit,
  `hardware.graphics.enable`, a nerd font.
- Added `quickshell` as a flake input (`github:quickshell-mirror/quickshell`,
  the GitHub mirror of the canonical `git.outfoxxed.me` repo — used the
  mirror for reliable nix fetching). Added `quickshell.packages.<system>.
  default` to `erdembozkurt`'s home-manager packages **directly in the
  nixosConfigurations block, not the shared homeModule** — quickshell only
  makes sense on Linux+Hyprland, so darwin's package set stays untouched.
- One real bug hit and fixed: `pkgs.greetd.tuigreet` doesn't exist in
  current nixpkgs (it's `pkgs.tuigreet`, top-level — got flattened out of
  the `greetd` namespace at some point).
- **Confirmed working end-to-end on the VM**: `nixos-rebuild switch`
  succeeds, but `greetd` doesn't take over `tty1` until an actual reboot
  (live-switch doesn't restart login-target units —
  `X-RestartIfChanged=false` on the greetd unit). After rebooting: tuigreet
  prompt appears in the UTM window, login as `erdembozkurt`/`changeme`
  launches straight into a working Hyprland session (GPU/display works fine
  through UTM's virtio-gpu). Currently showing Hyprland's stock default
  config/wallpaper since **no custom `hyprland.conf` or quickshell config
  exists yet** — that's the next chunk of work.

## Task #5: Hyprland base config -- lessons from a long debugging detour

- **Hyprland's config format matters at first boot.** On a fresh VM with no
  config, Hyprland auto-generates `~/.config/hypr/hyprland.lua` (the new
  native Lua config API) and commits to that provider for the running
  session. If you stow a classic `hyprland.conf` afterward, Hyprland keeps
  using the stale `hyprland.lua` until you delete it and reboot -- a plain
  `hyprctl reload` isn't enough to switch providers, only to reload within
  the same one. `hyprctl systeminfo | grep configProvider` tells you which
  one is actually active (`lua` vs `hyprlang`).
- **Classic `hyprland.conf`/`hyprlang` is deprecated as of Hyprland 0.55**
  and stated to be dropped within 1-2 releases. We're on 0.56.2. Config here
  is written in **Lua** (`hyprland.lua`, using the `hl.*` API) specifically
  to avoid near-term rework -- see the real Hyprland-shipped example at
  https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua for
  syntax (fetched directly since the wiki pages are mostly JS-rendered and
  don't return real content through WebFetch). One API gotcha hit:
  `dwindle.pseudotile` was removed entirely in 0.55+ (pseudo-tiling is now
  per-window only, via a dispatcher/windowrule), not renamed -- caused a
  "config has errors" banner until removed.
- **`hyprctl dispatch` syntax changed under the Lua provider too** -- it now
  expects a Lua expression, e.g. `hyprctl dispatch 'hl.dsp.exec_cmd("ghostty")'`,
  not the old `hyprctl dispatch exec ghostty`.
- **Long "no input reaching Hyprland" detour, mostly a red herring.** After
  wiring up keybinds, `SUPER+Return` (etc.) appeared completely dead --
  spent a long stretch suspecting a real UTM/Apple-Virtualization keyboard
  bug (this is a genuine, documented class of bug --
  https://github.com/utmapp/UTM/issues/4409,
  https://github.com/utmapp/UTM/issues/5284 -- workaround is disabling "Use
  Apple Virtualization" in the VM's settings and falling back to QEMU, at a
  real performance cost). Turned out the actual root cause was much
  dumber: **neither `kitty` nor `ghostty` were ever installed** --
  `packages.nix` never had them (kitty/ghostty are installed via Homebrew on
  macOS, outside this flake entirely), so every `exec_cmd("kitty")` was
  silently failing regardless of whether the keypress reached Hyprland at
  all. Confirmed by spawning a terminal directly via
  `hyprctl dispatch 'hl.dsp.exec_cmd("ghostty")'` over SSH (bypassing
  keybinds/keyboard entirely) once the packages existed -- it opened fine,
  and typing into it worked, and *then* the actual `SUPER+Return` keybind
  worked too. There may still have been a real transient UTM input-capture
  drop mixed in at some point (mouse worked, keyboard didn't, for one
  stretch, and re-clicking into the window fixed it) but it wasn't the
  primary blocker. **Lesson: verify the target binary is actually
  installed before debugging input/capture layers.**
- Added `kitty` and `ghostty` to `packages.nix`'s Linux set (both installed
  via Homebrew on macOS, so this is Linux-only, doesn't touch darwin).
  Both are kept: `ghostty` is the actual daily driver terminal and is now
  the `hyprland.lua` default (`SUPER+Return`); `kitty` stays too because
  `helper_scripts/bin/helpers/kitty-to-ghostty` converts kitty theme files
  to ghostty format, i.e. kitty is the source-of-truth format for theming
  even though it's not the terminal actually used day to day.
- **Confirmed working now**: `SUPER+Return` opens ghostty, `SUPER+Q` closes
  the focused window, keyboard input reaches the guest reliably. Not yet
  tested: workspace switching binds, `wofi` launcher (`SUPER+D`), the
  quickshell bar (still just the placeholder clock/workspace QML from
  earlier, never actually confirmed rendering -- restart it with
  `pkill quickshell; quickshell &` and check).

## Current session update

- Confirmed the VM's active Hyprland/quickshell config was not lost:
  `~/.config/hypr/hyprland.lua` and `~/.config/quickshell` are symlinked
  into `~/dotfiles`, and the local worktree versions match the VM copies.
- `scripts/stow.sh` is now OS-aware:
  - Darwin keeps the existing macOS/private package list.
  - Linux stows the shared packages plus `hyprland` and `quickshell`, and
    does not include macOS-only/private dirs.
  - The script resolves the repo root from its own path, targets `$HOME`,
    supports forwarding stow flags such as `-n -v`, and skips missing stow
    packages with a warning. This matters because the VM's hand-synced
    `~/dotfiles` currently lacks `ghostty/`.
- Added `hyprland/.stow-local-ignore` so a stale VM-only
  `hyprland/.config/hypr/hyprland.conf` stub does not get linked. After
  applying stow on the VM, `~/.config/hypr/hyprland.conf` is absent and
  `hyprctl systeminfo` reports `configProvider: lua`.
- Added `wl-clipboard` to Linux packages and updated `helper_scripts/bin/
  pbcopy` + `pbpaste` to use `wl-copy`/`wl-paste` under Wayland, falling
  back to `xclip` otherwise. Ran `sudo nixos-rebuild switch --flake
  ~/dotfiles#utm-aarch64` on the VM using the throwaway test password, and
  verified an explicit `~/bin/pbcopy` -> `~/bin/pbpaste` Wayland clipboard
  round-trip returned `vm-wayland-clipboard-test`.
- Verification completed:
  - local `nix flake check --no-build` passes;
  - local `nix build .#homeConfigurations.erdembozkurt.activationPackage
    --no-link` passes, so the Darwin Home Manager path still builds;
  - VM `nix build .#nixosConfigurations.utm-aarch64.config.system.build.
    toplevel --no-link` passes;
  - VM switch completed successfully.
- VM `~/dotfiles` still has an unrelated modified binary at
  `helper_scripts/bin/tmux-mover` from previous work. It was not touched in
  this session and should not be overwritten without checking why it differs.

## Current session update (2)

- Task #3 closed out: confirmed the quickshell bar genuinely renders (a real
  layer-shell surface, `hyprctl layers` shows a 960x32 `quickshell`-namespace
  layer at level 2), workspace-switching dispatchers work
  (`hl.dsp.focus({workspace=N})` moves the active workspace), and the wofi
  launcher opens and renders (`hl.dsp.exec_cmd("wofi --show drun")` produces
  a real `wofi`-namespace layer). All verified over SSH via `hyprctl
  dispatch`, same bypass pattern used earlier for `SUPER+Return`.
- Task #5 started with the Keychain → `secret-tool` port (chosen as the
  first sub-piece since `wg-manager`/`ts-manager`/`low-power-mode-toggle.sh`
  all depend on it). User does not use macOS Keychain day-to-day (uses
  Bitwarden) but confirmed `secret-tool`/libsecret — the direct Keychain
  analog — is fine for this narrow local-sudo-password use case; no need to
  wire up Bitwarden CLI for it.
  - `helper_scripts/bin/helpers/pass.sh` branches on `uname`: macOS keeps
    `security find-generic-password -l "macos root password"`, Linux uses
    `secret-tool lookup purpose sudo-password`. Shebang fixed to
    `#!/usr/bin/env bash` (was `#!/bin/bash`).
  - Added `libsecret` to `packages.nix`'s Linux set.
  - Added `services.gnome.gnome-keyring.enable` and
    `security.pam.services.greetd.enableGnomeKeyring = true` to
    `nixos/modules/desktop-hyprland.nix` so `secret-tool` has a Secret
    Service backend, unlocked automatically on graphical login via PAM.
  - **Not yet done**: `wg-manager`, `ts-manager`, `low-power-mode-toggle.sh`
    still won't run on Linux — they call `pass.sh` fine now, but have their
    own macOS-only bodies (`networksetup`, `route -n get default`,
    `/opt/homebrew/etc/wireguard`, `pmset`) that still need porting.
    `list-apps` (`mdfind`) also untouched. These are the actual next steps
    within task #5.
  - Verified end-to-end on the VM: stored a test secret with `secret-tool
    store --label="linux root password" purpose sudo-password`, confirmed
    `~/bin/helpers/pass.sh` retrieved it correctly, then cleared it with
    `secret-tool clear`. Note: the keyring's default "login" collection is
    only auto-created/unlocked by PAM **at graphical login time** — an
    already-running Hyprland session (or a bare SSH shell) started before a
    `nixos-rebuild switch` that enables this won't have it. Verified this
    session by unlocking manually against the running daemon
    (`printf '<pass>\n' | gnome-keyring-daemon --unlock`); a real reboot +
    tuigreet login should make this automatic going forward, but that's not
    yet confirmed — worth checking next session.

## VM disk-hang incident (2026-08-21)

- Mid-build (`nix build .#nixosConfigurations.utm-aarch64...toplevel` while
  adding gnome-keyring), the VM's disk I/O hung completely — every SSH
  command touching disk (`df -h`, even `cat /proc/<pid>/status` variants)
  froze indefinitely, not just the nix build. `ps` showed the build's
  `nixbld1` helper process stuck in `D` (uninterruptible disk sleep) for
  30+ minutes with zero CPU time accrued — a genuine virtio-blk-level hang,
  not just a slow/large build. Likely adjacent to the same class of UTM
  virtualization flakiness noted below for keyboard input.
- Fix: `utmctl stop nixos-utm-aarch64 --kill` (graceful `--force` stop
  wasn't tried since the guest was clearly unresponsive) then `utmctl start
  nixos-utm-aarch64` from the Mac. Came back up clean, disk healthy
  afterward (`df` showed 46G free / 23% used — this was never a disk-space
  issue, just an I/O hang). Rebuild succeeded on retry with no config
  changes needed.
- `utmctl` (Homebrew, already installed) is the CLI for controlling the VM
  from the Mac without touching the UTM GUI — `list`/`start`/`stop
  --kill`/`status`/`ip-address` are the useful ones for this workflow.
- **If a VM command hangs for more than ~1-2 minutes with no output, suspect
  a disk/IO hang before assuming it's just a slow build** — check for a
  process stuck in `D` state via `ps aux`, and don't keep retrying
  disk-touching commands against a hung guest; restart it via `utmctl`
  instead.

## Housekeeping

- Mac's `/nix` store was tight on space (90% full, ~12Gi free) — ran
  `nix-collect-garbage --delete-older-than 14d`, freed ~49GiB (14,211 store
  paths). `/nix` now at 44% used, ~64Gi free. **Done.**

## Current session update (3)

- Ported `wg-manager` and `ts-manager` to Linux (task #5 continues):
  - `wg-manager`: `interfaces_dir` branches on `uname`
    (`/opt/homebrew/etc/wireguard` Darwin, `/etc/wireguard` Linux).
    Shebang fixed to `#!/usr/bin/env bash`. Added `wireguard-tools` to
    `packages.nix`'s Linux set.
  - `ts-manager`: `_primary_service`/`_configure_dns`/`_restore_dns` branch
    on `uname`. macOS keeps `networksetup`; Linux resolves the default
    interface via `ip route show default` and manages a DNS override with
    openresolv's `resolvconf -a/-d` instead of saving/restoring explicit
    server lists — `resolvconf` merges automatically so there's nothing to
    save. **`resolvconf` didn't need adding to `packages.nix`** — it's
    already provided system-wide by NixOS's default networking module
    (confirmed via `readlink -f $(which resolvconf)` on the VM before
    assuming it needed packaging). Shebang fixed.
  - Verified on the VM: both scripts pass `bash -n`, `wg`/`wg-quick`
    install and resolve on `$PATH`, `wg-manager status` runs the full path
    through to `sudo -S wg show` correctly (failed only on an intentionally
    empty test secret, not a script bug), and a manual
    `resolvconf -a '<iface>.tailscale' <<< nameserver ...` /
    `resolvconf -d` round-trip against the VM's real `/etc/resolv.conf`
    confirmed the override/restore mechanism works exactly as
    `_configure_dns`/`_restore_dns` expect. No live headscale connection
    available to test the full `ts-manager up`/`down` flow end-to-end —
    that's still open for whenever real headscale credentials are on hand.
  - Still remaining in task #5: `low-power-mode-toggle.sh` (`pmset` →
    `powerprofilesctl`/`upower`), `list-apps` (`mdfind` → Linux app
    listing), hammerspoon's window/hotkey logic → Hyprland config,
    blueutil → `bluetoothctl`, `hs.chooser` UI pattern (~8 hammerspoon
    files) → a Linux launcher, notifications → reuse
    `tmux/tmux-mover/notify.go`'s existing cross-platform pattern. User
    has said hammerspoon itself is the big remaining chunk and explicitly
    wants it done in a later session, not now.

## Task #5 remaining work, sized (for picking session order)

Small, mechanical, one script each, no new subsystem — **all done**, see
"Current session update" entries above:
- `low-power-mode-toggle.sh`: `pmset` → `powerprofilesctl`/`upower`
- `list-apps`: `mdfind` → a Linux app-listing equivalent (`.desktop` file
  scan, or similar)
- blueutil → `bluetoothctl`, for the standalone `tmux_bluetooth.sh` usage.
  (`bt_menu.lua`'s own blueutil calls are separate and stay with the
  deferred hammerspoon chunk below.)

Medium:
- Task #4 (separate numbered task, but similar weight): add an
  x86_64-linux host + build-only CI check. Mostly config, no new logic.

Large — hammerspoon → Hyprland/Linux. Explicitly deferred to its own
session, started 2026-08-23. The file-count/line-count inventory from
earlier sessions (below this point until superseded) turned out to be
unreliable for keep/drop calls — a same-session correction found real
cross-file callers a shallow read/grep missed (see "Hammerspoon
call-graph audit" below). Do not judge any file's droppability in
isolation again; check the audit's per-file caller list first.

### Hammerspoon call-graph audit (2026-08-23)

A background agent read all 27 `.lua` files + 3 Spoons and built a real
cross-reference (who requires/calls whom, by exact function name, not
just "file X requires file Y"). Full per-file detail lives in this
session's transcript, not reproduced here — the load-bearing findings:

- **Confirmed actually dead** (commented out in `init.lua`, zero callers
  anywhere): `chrome_tab_switcher.lua` (superseded in-repo by
  `firefox_tab_switcher.lua` + the Firefox native-messaging bridge) and
  `google_meet_mic_toggle.lua`. Safe to drop outright, no port needed.
- **`helpers.lua` is the real backbone** — 13 callers
  (`action_menu`, `bt_menu`, `firefox_tab_switcher`, `fuzzy_window_switcher`,
  `menu_item_search`, `rapid_toggle`, `scoped_hotkeys`, `sleepwatcher`,
  `state_switcher`, `text_expander`, `macos_helpers`, `init.lua`, plus the
  dead `chrome_tab_switcher`). Cannot be dropped; needs function-by-function
  porting (fuzzy-search glue, app-scoped hotkeys, browser bridge commands,
  debounce, etc.), not a whole-file judgment.
- **`macos_helpers.lua` has 6 real callers**, not "mostly droppable" as an
  earlier same-session pass wrongly guessed: `action_menu`, `bt_menu`,
  `mouse_snap_window`, `rapid_toggle` (10 of its functions alone),
  `sleepwatcher`, `theme_sync`. Each exported function needs its own
  keep/drop/port call, not the file as a whole.
- **`globals.lua`** — 5 callers, just keybind modifier constants (`hyper`,
  `ctrl_alt`). Trivial, unblocks nothing risky — good first port.
- **`fzy.lua`** — only required by `helpers.lua` (single-quote
  `require('fzy')`, which a double-quote-only grep missed — a live example
  of why this audit re-read full file contents instead of grepping), but
  load-bearing for every chooser's fuzzy search since `helpers.lua` sits
  under nearly everything.
- **The three Spoons** (`ShiftIt`, `MenubarFlag`, `EmmyLua`) are each used
  by exactly one file (`window_manager.lua`, `menubar_colors.lua`,
  `init.lua` respectively) — the original single-file assessment held up
  for these three specifically.
- **Everything else is a "leaf"**: reachable from `init.lua`, but no
  sibling `.lua` file depends on it, so each can be evaluated/ported
  independently without a cross-file blast radius — `amphetamine`,
  `bt_menu`, `kb_battery`, `weather`, `spotify`, `now-playing`,
  `state_switcher`, `scoped_hotkeys`, `mouse_snap_window`,
  `mouse_position_indicator`, `theme_sync`, `text_expander`, `action_menu`,
  `menu_item_search`, `firefox_tab_switcher`, `fuzzy_window_switcher`,
  `reload`, `window_manager`.
- **No code outside `hammerspoon/` calls into it** (only reference is
  `scripts/stow.sh` listing it as a stow package name). Hammerspoon files
  *do* call out extensively to `~/bin/helpers/*` (already-ported scripts)
  and directly to `~/Documents/bitbar_plugins/state-switcher.5m` (the
  bitbar/state-switcher binary — still an open "Decisions made" item at
  the top of this file).

### Direction decided (2026-08-23), supersedes the old "hs.chooser
unification" and "probably drop" framing above

- **The `hs.chooser`-driven action files are not being dropped.** They get
  integrated as entries/modes in the existing Quickshell launcher
  (`SUPER+D` / `launcher --all`, see `helper_scripts/bin/launcher` +
  `launcher-items` + `quickshell/.config/quickshell/plugins/launcher/`,
  already built this migration) rather than becoming separate standalone
  pickers. This covers `bt_menu.lua`, `action_menu.lua`,
  `firefox_tab_switcher.lua`, `state_switcher.lua` (data path already
  surfaced via `launcher-items --states`), `text_expander.lua`,
  `fuzzy_window_switcher.lua` (already covered by `launcher --windows`).
  `menu_item_search.lua` stays a likely-drop (macOS AXMenuBar
  introspection, no Linux equivalent) since it doesn't fit the
  data-source-into-launcher pattern the others do.
- **Some of these should also stay directly keybindable**, not
  launcher-only — e.g. a bluetooth toggle callable both as a launcher entry
  and its own hotkey. Design each integration with both paths in mind
  rather than assuming launcher-only access.
- **Status/menubar widgets become Quickshell bar items**, not 1:1 ports:
  `kb_battery.lua`, `weather.lua`, `now-playing.lua`/`spotify.lua`,
  `theme_sync.lua`. Look at Omarchy's own equivalents for patterns before
  building ours — local reference checkout at
  `/Users/erdembozkurt/personal-repositories/junk/omarchy/`, relevant
  dirs: `shell/plugins/services/battery/` (Service.qml + BatteryModel.js),
  `shell/plugins/services/media/` (Service.qml + BarWidget.qml +
  MediaModel.js — has a ready-made bar widget shape to reference),
  `shell/plugins/services/nightlight/` and `shell/plugins/services/idle/`
  (possible `theme_sync.lua`/idle-related analogs). Same "inspiration not
  adoption" stance as the launcher/Commons.Color work already: borrow the
  shape, not the plugin-registry machinery.

Recommended order: `globals.lua` first (trivial, unblocks nothing risky),
then decide the launcher-integration shape for one chooser file end to end
before doing the rest (same "get one real thing working, then repeat"
pattern that worked for the launcher itself), then bar widgets last once
that shape is proven.

### `reload.lua` -- drop, not port (2026-08-23)

Tried porting `reload.lua` (hyper+R -> `hs.reload()`) as the first small
`globals.lua`-caller slice: added `SUPER+CTRL+R` -> `hyprctl reload`.
Removed it again after confirming (Hyprland's own docs/news post, then
verified empirically on the VM -- editing `hyprland.lua` and watching the
bind disappear with zero manual reload) that **Hyprland already
auto-reloads its Lua config on save** via `inotify`. Hammerspoon's
`hyper+R` existed specifically because Hammerspoon does *not* auto-reload
-- that need doesn't carry over. Net diff: none, this file is a pure drop.
Lesson: check whether the *problem* a Hammerspoon binding solves still
exists on Hyprland before porting the binding itself.

## Current session update (4)

- Ported the two small task #5 items: `low-power-mode-toggle.sh` and
  `list-apps`.
  - `low-power-mode-toggle.sh`: branches on `uname`. macOS keeps the
    `pmset`/Keychain flow unchanged. Linux uses `powerprofilesctl`, toggling
    between `power-saver` and `balanced` (no direct boolean equivalent to
    macOS's low-power-mode flag, so this is the closest analog). Added
    `services.power-profiles-daemon.enable = true;` to
    `nixos/modules/desktop-hyprland.nix` and `power-profiles-daemon` to
    `packages.nix`'s Linux set (for `powerprofilesctl` on `$PATH` outside the
    systemd service context too).
  - `list-apps`: branches on `uname`. macOS keeps `mdfind`/`find` unchanged.
    Linux scans `.desktop` files across
    `/run/current-system/sw/share/applications` (Nix-installed apps),
    `/usr/share/applications`, Flatpak's system/user export dirs, and
    `~/.nix-profile` / `~/.local/share/applications`. No callers found
    elsewhere in the repo (only referenced from this file), so this is a
    standalone listing tool, not wired into anything yet.
  - Verified on the VM (back up after the disk-hang incident, see above):
    `nixos-rebuild switch` succeeded, `list-apps` lists real `.desktop`
    entries. `low-power-mode-toggle.sh` initially failed when run over SSH
    with a polkit `AccessDenied` on
    `org.freedesktop.UPower.PowerProfiles.switch-profile` — `pkaction
    --verbose` showed this action is `implicit active: yes`, i.e.
    auto-authorized only for an active local seat session, and an SSH login
    has no seat. Confirmed this by fully testing it properly instead of
    accepting the gap: added a temporary `services.greetd.settings.
    initial_session` (autologin straight into Hyprland as erdembozkurt,
    VM-only, never committed), rebooted so it took a real seat0 session,
    then used the same `hyprctl dispatch 'hl.dsp.exec_cmd(...)'` IPC trick
    from the earlier keyboard-input debugging session to run the toggle
    script *inside* that session over SSH (inheriting its seat instead of
    SSH's own). Confirmed both directions cleanly:
    `balanced` → `power-saver` → `balanced`, no errors. Reverted the
    autologin config and rebooted again immediately after — confirmed back
    to the normal tuigreet prompt (`loginctl list-sessions` shows only the
    greeter on seat0 again). **Fully verified working, both directions.**
  - `nix flake check --no-build` and the darwin
    `homeConfigurations.erdembozkurt.activationPackage` build both still
    pass — darwin path untouched by this change.

## Current session update (6)

- Went looking for the "notifications" medium task item (reuse
  `tmux/tmux-mover/notify.go`'s cross-platform pattern for scripts that
  notify via macOS-only mechanisms) and found it isn't a standalone task:
  grepped the whole repo for `osascript`/`terminal-notifier`/`hs.notify`
  outside `tmux-mover` (which already has working cross-platform notify
  logic, confirmed portable in an earlier session) and the only real
  notification call sites are 4 `hs.notify.new(...)` mute-toggle banners in
  `hammerspoon/.hammerspoon/scoped_hotkeys.lua` — already inside the
  deferred hammerspoon chunk (that file is one of the keybind-port files
  listed there). Everything else `osascript`-related
  (`set_wallpaper.sh`, `get-focus-mode`, `macos-now-playing.js`) does
  something unrelated to notifications (wallpaper, Focus-mode status,
  now-playing info) and isn't in scope for this item. Removed the
  standalone "Notifications" line from the sized-remaining-work list below
  since it has no work outside hammerspoon.

## Current session update (5)

- Ported `blueutil` → `bluetoothctl` for
  `helper_scripts/bin/helpers/tmux_bluetooth.sh` (the tmux status-line
  Bluetooth icon, called from `tmux_status_right.sh`). This is a standalone
  script, separate from hammerspoon's `bt_menu.lua`/`macos_helpers.lua`
  blueutil usages, which stay macOS-only and are part of the deferred
  hammerspoon chunk (task #5's large item) — not touched this session.
  - Branches on `uname`, byte-for-byte preserving the nerd-font icon glyphs
    on both branches (edited via a Python byte-level rewrite rather than
    the string-match Edit tool, since the icons don't compare reliably as
    text).
  - Added `hardware.bluetooth.enable = true;` to
    `nixos/modules/desktop-hyprland.nix` (bluetoothd won't start without
    it) and `bluez` to `packages.nix`'s Linux set (for `bluetoothctl` on
    `$PATH`).
  - **Real bug caught during VM verification**: the UTM VM has no Bluetooth
    controller at all (`ConditionPathIsDirectory=/sys/class/bluetooth`
    fails, confirmed via `systemctl status bluetooth`), and in that state
    plain `bluetoothctl show`/`bluetoothctl devices Connected` block
    forever waiting on a D-Bus interface that never appears — not specific
    to this VM, the same would happen on any real machine with Bluetooth
    disabled/rfkilled. Since this script feeds the tmux status line, a hang
    here would freeze the whole status bar. Fixed by wrapping both
    `bluetoothctl` calls in `timeout 1`.
  - Verified on the VM after the fix: `bash tmux_bluetooth.sh` returns in
    ~2s (exit 0) instead of hanging, and its output byte-for-byte matches
    the macOS "off" branch's icon (`ef 96 b1`), which is the correct state
    to fall into with no adapter.
  - `nix flake check --no-build` and the darwin
    `homeConfigurations.erdembozkurt.activationPackage` build both still
    pass.

## Task list state (see TaskList tool for live status)

1. Set up UTM aarch64 NixOS VM — **done**
2. Restructure flake.nix for multi-platform — **done**
3. Bring up cross-platform apps on the VM — **done**. Wayland clipboard,
   OS-aware `stow.sh`, quickshell bar, workspace switching, and wofi
   launcher all verified working.
4. Add x86_64-linux host + build-only CI check — **not started**
5. Port macOS-only pieces to Hyprland/Linux — **in progress**. Done:
   Keychain → `secret-tool`, `wg-manager`, `ts-manager` (DNS override via
   resolvconf; full up/down flow not tested live, no headscale creds on
   hand), `low-power-mode-toggle.sh` (pmset → powerprofilesctl; fully
   verified both directions via a temporary autologin session, see above),
   `list-apps` (mdfind → `.desktop` file scan), `tmux_bluetooth.sh`'s
   standalone blueutil usage → bluetoothctl (real hang bug found + fixed
   with a `timeout` guard, see above). Still remaining: hammerspoon's
   window/hotkey logic → Hyprland config (explicitly deferred to a later
   session — the big one, includes its own separate blueutil usages in
   `bt_menu.lua`/`macos_helpers.lua`, and the 4 `hs.notify.new(...)`
   mute-toggle banners in `scoped_hotkeys.lua` — that's the entirety of
   the "notifications" surface, `tmux-mover` already handles its own via
   `notify.go`), `hs.chooser` UI pattern (~8 hammerspoon files) → a Linux
   launcher.
6. Decide GUI app carryover (Brewfile audit) — **not started**, deferred by
   user request.
7. Old physical x86 machine real-hardware pass — **not started**, deferred
   until both VMs work end to end.

## Gotchas for whoever picks this up

- **Cross-building `aarch64-linux` from this `aarch64-darwin` Mac doesn't
  work** without a Linux builder (`nix.linux-builder` in nix-darwin, not set
  up — a system-level change, ask before enabling). `nix flake check`
  validates evaluation; actual builds have to happen on the VM itself over
  SSH, which is the workflow used throughout this session.
- **New files must be `git add`ed** (even just staged, no commit needed) in
  a worktree before `nix flake check`/`nix build` can see them — flakes only
  read git-tracked files.
- **Sandboxed `Bash` tool in this environment blocks multi-line/heredoc SSH
  commands** with a "too complex to verify... worktree" error — keep remote
  commands on one line (`&&`-chained), or write a script and `scp` it over.
- **The sandboxed `Bash` tool also blocks any command containing the literal
  word `source`** as a bare argument (e.g. `rsync .../source ...`), treating
  it as a shell `source` builtin call regardless of context — a false
  positive specific to this environment. Workaround: glob it
  (`bitbar_plugins/s*ce`) or reference it through a variable so the literal
  token doesn't appear.
- **NixOS has no `/bin/bash`**, only `/bin/sh` and `/usr/bin/env`. Any script
  synced from the macOS side with a literal `#!/bin/bash` shebang will fail
  with "bad interpreter" until changed to `#!/usr/bin/env bash`.
- The VM's `~/dotfiles` is a hand-synced copy, not a real git clone — if you
  want a cleaner setup, consider pushing the `nixos` branch to GitHub and
  cloning it on the VM properly (needs deploy key or similar, wasn't set up
  this session to keep the private submodules out of it easily).

## Current session update (7)

- User clarified the near-term goal: **ignore the x86 task for now**. The
  priority is making the existing UTM aarch64 NixOS desktop VM usable as a
  practical work machine on this Mac.
- First VM-usability pass:
  - Added Linux-only baseline desktop packages: `firefox-devedition`,
    `xdg-utils`, `libnotify`, and `pavucontrol`.
  - Made tmux status helpers quieter/portable on Linux:
    `tmux_battery.sh` now uses `/sys/class/power_supply` and
    `powerprofilesctl` on Linux while preserving the macOS `pmset` path;
    `tmux_focus_mode.sh` returns quietly outside macOS; `tmux_state.sh` and
    the media segment in `tmux_status_right.sh` now skip cleanly when the
    BitBar/state-switcher UI backend is not installed.
- Local verification completed:
  - `bash -n` passes for the touched tmux helper scripts.
  - `nix flake check --no-build` passes.
  - `nix build .#homeConfigurations.erdembozkurt.activationPackage --no-link`
    passes, so the Darwin Home Manager path still builds.
  - VM home package list evaluates locally.
- VM-side verification completed after user approved treating the current VM
  as throwaway:
  - The VM hit another UTM disk I/O hang during the first build attempt,
    same class as the 2026-08-21 incident above (`nix-daemon`, a child
    `bash`, and even `df -h /nix /` stuck in `D` state).
  - Restarted it with `utmctl stop nixos-utm-aarch64 --kill` and
    `utmctl start nixos-utm-aarch64`.
  - Re-synced the touched files, reran `nix build
    .#nixosConfigurations.utm-aarch64.config.system.build.toplevel
    --no-link`, and it passed.
  - Ran `sudo nixos-rebuild switch --flake .#utm-aarch64`; switch completed
    successfully.
  - Smoke checks passed: `firefox-devedition`, `xdg-open`, `notify-send`,
    and `pavucontrol` resolve on the user's profile path; the touched tmux
    helpers run cleanly on Linux.
- Important direction from user: **do not treat the VM as stateful**. The VM
  is disposable for now; work should move toward making the setup
  reproducible from repo/config/bootstrap steps rather than relying on
  guest-local hand edits or manually accumulated state.

## Current session update (8)

- Started launcher/picker platform spike based on user clarification: the
  desired tool is not necessarily a Raycast clone, but a polished reusable
  fuzzy/picker UI that can be fed arbitrary lists over time. It should handle
  apps, scripts/actions, files/calculator/translation, and custom lists such
  as windows or browser tabs, without forcing everything into one global
  mixed list.
- Agreed first migrated list should be immediately usable and not depend on
  unresolved browser integration. Chosen spike list: **Hyprland window
  switcher**.
- Added Linux-only packages for comparison:
  - `walker`
  - `vicinae`
- Added `helper_scripts/bin/window-switcher`:
  - `--list`: formats live Hyprland clients from `hyprctl clients -j`.
  - `--walker`: pipes the list through `walker --dmenu`, then focuses the
    selected window with `hyprctl dispatch focuswindow address:<addr>`.
  - `--vicinae`: pipes the same list through `vicinae dmenu`, then focuses
    the selected window the same way.
  - Defensive behavior: when run outside a Hyprland session (e.g. plain SSH
    where `HYPRLAND_INSTANCE_SIGNATURE` is unset), it exits quietly instead
    of surfacing `jq` parser errors.
- Added Hyprland comparison keybinds:
  - `SUPER+Tab`: `window-switcher --walker`
  - `SUPER+Shift+Tab`: `window-switcher --vicinae`
  - Also starts `vicinae server` on Hyprland startup because Vicinae's dmenu
    CLI requires its server socket; Walker dmenu does not require a separate
    server for this test.
- Verification:
  - Local `bash -n helper_scripts/bin/window-switcher` passes.
  - Local `nix flake check --no-build` and Darwin activation build passed
    after adding the Linux-only packages.
  - VM `nix build
    .#nixosConfigurations.utm-aarch64.config.system.build.toplevel
    --no-link` passed; Walker and Vicinae were fetched from cache.
  - VM `nixos-rebuild switch --flake .#utm-aarch64` completed successfully.
  - VM command checks: `walker`, `vicinae`, and `~/bin/window-switcher`
    resolve.
  - Spawned a Ghostty window via Hyprland IPC and confirmed
    `window-switcher --list` outputs it correctly.
  - Walker UI smoke test: launching `window-switcher --walker` from Hyprland
    starts `walker --dmenu`.
  - Vicinae UI smoke test: `vicinae dmenu` initially failed until
    `vicinae server` was started; after starting the server, dmenu opens.
    Needs hands-on visual/interaction comparison in the VM.

## Current session update (9)

- User clarified the desired launcher architecture further:
  - Prefer owning our own item/action data model and scripts/CLIs.
  - Prefer feeding structured data into a reusable picker UI rather than
    immediately committing to a tool-specific extension system.
  - Extensions are not ruled out, but should not be the first/default step
    while the platform choice is still unsettled.
  - Long-term theming should follow the OS/current dotfiles theme flow, not
    become an isolated launcher-only theme.
- Added `helper_scripts/bin/launcher-spike`, a richer adapter spike:
  - Own neutral JSON model with `id`, `icon`, `title`, `subtitle`,
    `keywords`, and `actions`.
  - `--picker walker` and `--picker vicinae` render the same data through
    the selected CLI picker.
  - Uses a second picker view for actions after item selection, so we can
    test multi-action UX without writing Walker/Vicinae extensions yet.
  - Demo items include power profile, Bluetooth, dotfiles project, state
    switcher, Hyprland Lua config, and translation placeholder, each with
    multiple actions.
- Added Hyprland comparison keybinds for the richer action-flow spike:
  - `SUPER+Alt+Tab`: `launcher-spike --picker walker --demo`
  - `SUPER+Alt+Shift+Tab`: `launcher-spike --picker vicinae --demo`
- Current finding from docs + installed CLI:
  - Walker has documented quick activation keys (`F1`-style by default and
    configurable) and dmenu can use richer columns via config.
  - Vicinae dmenu supports title/placeholder/section/window sizing, but does
    not expose Raycast-style item action panels or numeric row activation in
    the simple stdin/dmenu path. Vicinae script commands are one-shot entry
    points; Vicinae docs explicitly point to full extensions for complex
    rendered lists/grids/forms.
  - Therefore, with our preferred CLI-fed model, rich actions currently mean
    either a chained picker flow (what `launcher-spike` tests) or deeper
    tool-specific integration later.
- Visual-theme spike note:
  - Hand-written Walker and Vicinae theme/config attempts were tried and
    removed because they broke or looked wrong. Both tools should be tested
    with defaults for now.
  - Do not revive those guessed theme files. If launcher theming is revisited,
    start from real upstream examples or generated config. Long-term,
    launcher themes should be generated from the same theme source as
    terminal/nvim/quickshell rather than maintained by hand.

## Current session update (10)

- Vicinae was rejected for now because no documented/source-visible
  Raycast-style numeric row activation (`Cmd/Super+1..9`) was found.
- Walker is the chosen transitional picker:
  - Removed Vicinae from Linux packages and Hyprland startup/binds.
  - Changed `SUPER+D` from `wofi --show drun` to `walker`.
  - Kept `SUPER+Tab` as the live Walker-backed Hyprland window switcher.
  - Kept `SUPER+CTRL+Tab` as the Walker demo window list.
  - Kept `SUPER+ALT+Tab` as the Walker demo item/action flow.
  - Added a minimal stowed Walker config under `walker/.config/walker`.
- Numeric activation note:
  - Walker supports configurable `quick_activate` keys and valid modifiers
    include `ctrl`, `alt`, `shift`, and `super`.
  - Existing Hyprland `SUPER+1..5` workspace bindings were intentionally left
    unchanged for now. Walker quick activation remains on `F1..F9` until the
    global keybinding scheme is settled.
- Direction: keep our own item/action data shape in scripts for now so the UI
  can later move to quickshell without rewriting the launcher model.

## Current session update (11)

- User clarified the launcher direction again: **use Quickshell for this UI**,
  and build our own small abstractions on top of it rather than adopting
  Omarchy's plugin system wholesale.
- Local Omarchy repo is available at
  `/Users/erdembozkurt/personal-repositories/junk/omarchy/` and should be
  treated as a reference only. Useful patterns found:
  - one long-running Quickshell shell with IPC-opened panels/menus;
  - Hyprland Lua config split by concern;
  - declarative menu rows plus runtime providers;
  - Hyprland Lua dispatcher first, classic dispatcher fallback.
- Added `helper_scripts/bin/launcher-items`, the first local launcher
  abstraction. It emits UI-neutral item/action JSON for:
  - static actions/projects/docs;
  - live Hyprland windows via `hyprctl clients -j`;
  - existing `state-switcher.5m states-json` rows.
  Missing optional providers degrade to `[]` instead of failing the whole
  palette.
- Added `helper_scripts/bin/launcher`, a small durable wrapper around the
  Quickshell launcher IPC (`--all`, `--windows`, `--actions`, `--states`).
  The older `launcher-spike` demo script is intentionally not part of this
  path.
- Reworked `quickshell/.config/quickshell/shell.qml` from a bar-only
  placeholder into a small shell host:
  - keeps the top workspace/clock bar;
  - adds a Quickshell overlay command palette;
  - exposes `IpcHandler { target: "launcher" }`, so
    `quickshell ipc call launcher toggle all` opens the full palette and
    `... toggle windows` opens the window provider.
- Updated Hyprland binds:
  - `SUPER+D`: Quickshell full launcher;
  - `SUPER+Tab`: Quickshell window provider;
  - `SUPER+ALT+Tab`: Quickshell full launcher.
  Walker remains installed/configured for fallback/debug only.
- Updated window focus actions to use the Lua dispatcher first, with classic
  Hyprland dispatch fallback, matching Omarchy's compatibility pattern.
- Local validation completed on macOS:
  - `bash -n` passes for `launcher`, `launcher-items`, and `window-switcher`;
  - `launcher-items --all | jq ...` returns valid rows, including the current
    local state-switcher states.
- VM verification completed after syncing the touched files into
  `~/dotfiles`:
  - restarted Quickshell inside the running Hyprland session;
  - `quickshell ipc call launcher ping` returns `ok`;
  - `quickshell ipc call launcher toggle all` opens a real
    `dotfiles-launcher` overlay layer in `hyprctl layers`, and `close` hides
    it;
  - Quickshell logs show no QML errors after switching the bar from
    deprecated `height` to `implicitHeight` (only UTM/Mesa EGL warnings);
  - spawned a temporary Ghostty client, confirmed `launcher-items --windows`
    sees live Hyprland clients, and ran the generated focus action
    successfully.
  The VM client list was cleaned back to empty afterward.
- Fixed Ghostty's NixOS launch path after manual testing showed "zsh is
  missing": the config and startup script no longer hardcode `/bin/zsh`;
  they resolve `zsh` through PATH, including the NixOS profile/system paths.
  Verified `SUPER+Return` opens Ghostty in the VM.

## Current session update (12)

- Moved static launcher rows out of `launcher-items` into
  `launcher/.config/launcher/actions.json`, and added `launcher` to the
  Linux stow package list. `launcher-items` now reads
  `$XDG_CONFIG_HOME/launcher/actions.json` with a repo fallback for local
  testing. The committed rows are limited to real system/settings/script/tool
  entries we have explicitly wired today: power profile, Bluetooth,
  calculator, and Quickshell/Hyprland reloads. Lock, suspend, shutdown, and
  reboot remain launcher candidates to design later, not active actions.
- Extended the launcher provider model:
  - `--apps` scans `.desktop` entries and emits app rows that open through
    `launcher-open-desktop`;
  - `--tabs` is a first-class browser-tabs provider hook, backed by either
    `LAUNCHER_TABS_COMMAND` or
    `${XDG_CACHE_HOME:-$HOME/.cache}/launcher/browser-tabs.json`;
  - `--all` now combines apps, static actions, windows, state-switcher rows,
    and browser tabs.
- Added Linux-aware `bt-toggle` and `libqalculate` for the initial
  calculator workflow.
- Extended the Quickshell launcher UI with action selection:
  - selecting a row with one action runs it directly;
  - selecting a row with multiple actions opens an action list;
  - `Esc` backs out of the action list before closing the launcher.
- Replaced substring filtering with in-QML fuzzy scoring/ranking, so the
  combined list can be searched as one palette without exact contiguous
  matches.
- Follow-up correction: do not add lock/power-session actions before choosing
  the underlying tool and confirmation UX. A bare `loginctl lock-session` can
  exit successfully while doing nothing if no locker is installed.
- VM verification completed after cleaning stale VM-only launcher package
  files from an earlier experiment:
  - `launcher-items --actions` reads rows from the stowed JSON file;
  - Quickshell restarts cleanly with no QML errors;
  - `launcher --all` opens the `dotfiles-launcher` layer and `launcher
    --close` hides it.
- Removed the obsolete Walker/Vicinae experiment surface from active config:
  Walker is no longer installed, no longer stowed, and the old Walker-backed
  demo scripts/keybinds were removed. Vicinae was already absent from active
  config; remaining mentions are historical notes only.

## Next session note: helper script organization

- The growing set of desktop/launcher helper scripts should be organized before
  adding many more actions.
- Preferred shape:
  - `helper_scripts/bin/` contains only stable public commands intended to be
    called by users, Hyprland binds, launcher actions, or other top-level
    integrations.
  - `helper_scripts/libexec/` contains implementation scripts grouped by area.
- Candidate public commands:
  - `desktop lock`
  - `desktop lock-preview`
  - `desktop idle-status`
  - `desktop restart-shell`
  - `launcher open --all`
  - `launcher items --actions`
  - `launcher open-desktop <desktop-id>`
- Candidate internal layout:
  - `helper_scripts/libexec/desktop/lock`
  - `helper_scripts/libexec/desktop/lock-preview`
  - `helper_scripts/libexec/launcher/items`
  - `helper_scripts/libexec/launcher/open-desktop`
  - `helper_scripts/libexec/helpers/*`
- Keep compatibility wrappers such as `lock-screen`, `lock-preview`,
  `launcher-items`, and `launcher-open-desktop` briefly while migrating active
  configs. Remove them only after Hyprland binds, launcher actions, and VM
  verification use the new public commands.
- This should be a focused organization pass. Avoid changing lock behavior or
  launcher behavior while moving files.

## Current session update (13)

- Removed the dormant `hyprlock` fallback: the real lock screen has been the
  Quickshell `WlSessionLock` overlay since it was added, and `hyprlock` was
  never actually reached (`lock-screen` only fell back to it if quickshell
  was missing, which it never is). Deleted `hyprland/.config/hypr/
  hyprlock.conf`, removed `programs.hyprlock.enable` and the `hyprlock`
  package, and trimmed `lock-screen`'s fallback branch to just error out if
  the Quickshell IPC call fails. Commit `d6ed845`.
- Diagnosed and fully verified the lock screen's Sleep/Restart/Shutdown
  power buttons, which the user reported as inert:
  - Confirmed via `journalctl` that clicking did **not** invoke `systemctl`
    at all (no login1 activity), i.e. a real click-delivery bug, not a
    downstream one. Verified the `Process`/`runLockPowerAction` mechanism
    itself was fine by invoking it directly over a temporary debug IPC
    function.
  - After a Quickshell restart (to pick up the debug build), Sleep and
    Restart **both started working** via real clicks -- root cause never
    fully isolated, but restarting Quickshell resolved it. Confirmed via
    journal: `systemctl suspend`/`systemctl reboot` genuinely invoked.
  - Sleep exposed a separate real VM issue: UTM's Apple Virtualization
    backend does not cleanly resume a **guest-initiated** `systemctl
    suspend` (`utmctl start` errors "Operation not available" since UTM's
    own state machine never saw a UTM-level suspend). Recovery is the same
    `utmctl stop --kill` + `start` used for the disk-hang incidents.
    Restart, by contrast, recovered cleanly on its own (real reboot, UTM
    handles that fine). Shutdown was not separately live-tested but shares
    the identical code path.
  - Removed the temporary debug `console.log`/`notify-send` wrapper around
    `runLockPowerAction` after verification; both local and VM copies
    confirmed back to matching git HEAD exactly.
- Split `quickshell/.config/quickshell/shell.qml` (had grown to 1000+ lines
  mixing bar/lock/launcher) into `plugins/bar/Bar.qml`,
  `plugins/lock/Lock.qml`, `plugins/launcher/Launcher.qml`, plus a new
  `Commons/Color.qml`. Commit `71053c5`.
  - Directory-per-concern layout intentionally mirrors Omarchy's
    `shell/plugins/<name>/` shape (local reference checkout at
    `/Users/erdembozkurt/personal-repositories/junk/omarchy/`), without
    adopting their actual plugin *system* (no `manifest.json`, no
    `PluginRegistry`, no dynamic `Qt.createComponent` loading -- unneeded
    complexity for a personal single-user shell). The point is that a
    component copied from Omarchy later drops into a same-shaped folder
    with minimal rework.
  - Each plugin component takes `property var shell` (injected via
    `Bar { shell: shell }` etc. in `shell.qml`), matching Omarchy's
    `item.shell = shell` convention, even though nothing reads it yet --
    it's the ready-made hook for future cross-component/root-level state.
    This is **property injection**, not a singleton: Omarchy's own
    `shell.qml` explicitly documents avoiding `pragma Singleton` for
    mutable app state, because relative-path imports at inconsistent
    depths can silently resolve to separate singleton instances in their
    deeper plugin tree. Our plugin files are all at a uniform depth
    (`plugins/<name>/<Name>.qml`), so this particular failure mode doesn't
    apply to us, but the convention was kept for consistency/portability.
  - `Commons/Color.qml` **is** a true singleton (`pragma Singleton`,
    Quickshell's dedicated `Singleton` root type, imported via
    `import "../../Commons" as Commons`) -- safe here because it's
    read-only theme data at a consistent import depth, not live mutable
    state. Colors are organized **by surface**, not as flat semantic
    names (`Color.bar.*`, `Color.lock.*`, `Color.launcher.*`, each
    deriving from shared base tokens like `background`/`foreground`/
    `accent`/`danger`), matching Omarchy's `Color.lock.background`-style
    per-surface nesting exactly, since that shape is what supports
    per-surface re-theming later without a flat-namespace collision.
  - Explicitly scoped to *organizing* the existing hardcoded Catppuccin
    Mocha hex values as named tokens -- generating a palette from other
    sources (the user's actual long-term goal: "colors for everything
    will change") is deferred as its own, larger, cross-tool effort (would
    also touch kitty/nvim/wezterm, which each currently pick their own
    theme independently -- there is no unified theme source yet despite
    MIGRATION.md's earlier aspirational note about one).
  - Verified on the VM after every step (including two intermediate fixes:
    `Color.qml` needed `import QtQuick` for the `color` property type,
    initially missing): config loads with zero QML errors, bar layer
    renders, launcher opens/closes via IPC, lock locks/unlocks with the
    power buttons intact.

## Helper script organization -- done (2026-08-23, commit 7711d10)

The bin/libexec reorg above is complete: `desktop` (lock, lock-preview)
and `launcher` (items, open-desktop, plus its existing IPC-control flags)
are the public commands; implementation lives under
`helper_scripts/libexec/{desktop,launcher}/`. Old names kept as thin
compat wrappers. `helper_scripts/bin/helpers` was deliberately left in
place, not moved -- see the reasoning above.

## `bt_menu.lua` ported -- first proof of the launcher-integration shape
(2026-08-23)

Ported the hs.chooser device-picker piece of `bt_menu.lua` as the first
real test of "integrate into the existing launcher" from the direction
decided above. Added a `bluetooth_json()` provider to
`helper_scripts/libexec/launcher/items` (`--bluetooth` mode), following
the exact same shape as `windows_json`/`states_json`: paired devices via
`bluetoothctl devices Paired`, per-device connected state via
`bluetoothctl info <mac>`, one `toggle` action per device
(connect/disconnect). Wrapped every `bluetoothctl` call in `timeout 2`
-- same class of hang risk found and fixed earlier this migration in
`tmux_bluetooth.sh` when no adapter is present (confirmed on this VM,
which has none: gracefully returns a single "Bluetooth is off / Turn On"
item instead of an empty list or a hang).

Included in both `--all` and `--non-apps` aggregation, plus:
- a direct keybind, `SUPER+SHIFT+B` -> `launcher --bluetooth`, mirroring
  the original's standalone `ctrl+shift+alt+b` hotkey (the "some should
  stay independently keybindable" requirement from the direction above);
- a static `action:bluetooth-devices` entry in `actions.json` so it's
  also reachable from the main `SUPER+D` palette, alongside the
  pre-existing `action:bluetooth-toggle` (adapter power toggle, separate
  concern from per-device connect/disconnect).

`Launcher.qml` needed zero changes -- its provider-command wiring was
already generic (`--` + whatever `launcherMode` is set to), confirming
the launcher's shape genuinely supports adding new integrated sources
without touching the QML each time.

Verified on the VM: `launcher items --bluetooth` returns the graceful
off-state item, `launcher items --all` completes in ~2s (timeout guards
working, not hanging), both new binds registered (`hyprctl binds -j`),
and `launcher --bluetooth` opens the real Quickshell launcher layer via
IPC.

Not yet done for `bt_menu.lua`: the status-widget half (small
bar/menubar indicator showing bluetooth on/off) -- that's explicitly
deferred to the "bar widgets last" phase of the plan above, not part of
this chooser-integration slice.

While testing the bluetooth integration on the VM (via a temporary,
uncommitted `LAUNCHER_BLUETOOTH_MOCK` env-gated mock in
`libexec/launcher/items`, since the VM has no real adapter), a launcher
UX idea came up worth remembering for later: **nested lists**. Right now
every source (apps, windows, bluetooth devices, etc.) flattens its rows
directly into the one searchable list. The idea is twofold:
1. Sources like "Bluetooth Devices" could instead be a drill-down --
   selecting the source enters its own sub-list, rather than all its rows
   always being mixed into the top-level search.
2. But also selectively surface specific items *out of* a nested list
   into the top-level list when some condition makes them relevant (e.g.
   a currently-connected device, or a strong search-query match) --
   not an either/or with (1), both at once. Not designed or scoped yet,
   just captured so it's not lost before the launcher work continues.
