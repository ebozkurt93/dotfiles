# Shared across Linux hosts so the x86_64 host (task #4) can reuse it.
{
  pkgs,
  config,
  lib,
  ...
}: let
  # Derived from isNormalUser instead of hardcoding a username; throws if more/fewer than one exists.
  normalUsers = lib.filterAttrs (_: u: u.isNormalUser) config.users.users;
  primaryUser =
    if builtins.length (lib.attrNames normalUsers) == 1
    then lib.head (lib.attrValues normalUsers)
    else throw "desktop-hyprland.nix: expected exactly one isNormalUser account, found ${toString (builtins.length (lib.attrNames normalUsers))} (${toString (lib.attrNames normalUsers)})";
  dotfilesDir = "${primaryUser.home}/dotfiles";
  pythonWithEvdev = pkgs.python3.withPackages (ps: [ps.evdev]);

  # nixpkgs' pkgs.fira-code dropped the static "Retina" weight kitty/ghostty pin; fetch the classic release directly, matching macOS.
  firaCodeStatic = pkgs.stdenvNoCC.mkDerivation {
    pname = "fira-code-static";
    version = "6.2";
    src = pkgs.fetchurl {
      url = "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip";
      sha256 = "sha256-CUmRW6jrJNif2T0Qp/9iP0KDDXxf/D7L+WDk7K0+Pnk=";
    };
    nativeBuildInputs = [pkgs.unzip];
    unpackPhase = "unzip $src -d source";
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      cp source/ttf/*.ttf $out/share/fonts/truetype/
    '';
  };
in {
  programs.hyprland.enable = true;
  security.pam.services.dotfiles-lock = {};

  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-hyprland];
  };

  # nixpkgs' hyprland package doesn't install this, so graphical-session.target (xdg-desktop-portal, gvfs, ...) never activates without it.
  systemd.user.targets.hyprland-session = {
    unitConfig = {
      Description = "Hyprland session";
      BindsTo = ["graphical-session.target"];
      Wants = ["graphical-session-pre.target"];
      After = ["graphical-session-pre.target"];
      PropagatesStopTo = ["graphical-session.target"];
    };
  };

  xdg.mime.enable = true;
  xdg.mime.defaultApplications = {
    "image/png" = "imv.desktop";
    "image/jpeg" = "imv.desktop";
    "image/gif" = "imv.desktop";
    "image/webp" = "imv.desktop";
    "image/bmp" = "imv.desktop";
    "image/svg+xml" = "imv.desktop";
    "application/pdf" = "org.gnome.Evince.desktop";
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
      user = "greeter";
    };
  };

  hardware.graphics.enable = true;

  security.polkit.enable = true;
  security.rtkit.enable = true;

  # Required for home-manager's dconf.settings (system-wide dark theme default).
  programs.dconf.enable = true;

  # Secret Service backend for secret-tool (helper_scripts/bin/helpers/pass.sh).
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # powerprofilesctl; helper_scripts/bin/helpers/low-power-mode-toggle.sh
  services.power-profiles-daemon.enable = true;

  # UPower D-Bus service (battery/device info), separate from power-profiles-daemon; used by plugins/bar/Power.qml.
  services.upower.enable = true;

  # Backing D-Bus service for udiskie (packages.nix) to auto-mount removable drives.
  services.udisks2.enable = true;

  # Trash/network-mount (sftp, etc.) support for Thunar (packages.nix).
  services.gvfs.enable = true;

  # bluetoothctl; helper_scripts/bin/helpers/tmux_bluetooth.sh
  hardware.bluetooth.enable = true;

  # Quickshell's Networking module (plugins/bar/Network.qml) only has a NetworkManager backend.
  networking.networkmanager.enable = true;

  # services.openssh.openFirewall defaults to true, so SSH stays reachable on hosts that enable it.
  networking.firewall.enable = true;

  # Compressed RAM swap, tuned for zram not disk (values from Omarchy).
  zramSwap = {
    enable = true;
    memoryPercent = 100;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 150;
    "vm.vfs_cache_pressure" = 50;
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.dirty_background_bytes" = 67108864;
    "vm.dirty_bytes" = 268435456;
    "vm.dirty_writeback_centisecs" = 1500;
    "fs.inotify.max_user_watches" = 524288;
  };

  # Fixes flaky USB peripherals under aggressive power management; inert without real USB hardware.
  boot.extraModprobeConfig = "options usbcore autosuspend=-1";

  # Root/system slices only — no uwsm/app-slice split here yet to safely add user-slice policy without risking the compositor.
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableSystemSlice = true;
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Nerd-patched fonts rename the family/PostScript name terminal configs pin on, so both the nerd-patched (icons) and plain (name match) builds are needed.
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.symbols-only
    pkgs.jetbrains-mono
    firaCodeStatic
    # Rest of macOS's setup/install-fonts.sh list, kept for manual/occasional use.
    pkgs.input-fonts # Input Mono
    pkgs.noto-fonts # includes Noto Sans Mono
    pkgs.victor-mono
    pkgs.ibm-plex # includes IBM Plex Mono
    pkgs.iosevka
    pkgs.cascadia-code
    pkgs.twemoji-color-font # flat, open-licensed emoji style; set as the default emoji font below
  ];

  fonts.fontconfig.defaultFonts.emoji = ["Twitter Color Emoji"];
  # signal-desktop bundles its own Noto Color Emoji, which some apps request by name directly, bypassing the alias above.
  fonts.fontconfig.localConf = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <match target="pattern">
        <test name="family"><string>Noto Color Emoji</string></test>
        <edit name="family" mode="assign" binding="strong"><string>Twitter Color Emoji</string></edit>
      </match>
    </fontconfig>
  '';

  # Same firefox/policies/policies.json as macOS; __DOTFILES_DIR__ substituted the same way setup.sh does with sed.
  environment.etc."firefox/policies/policies.json".text =
    builtins.replaceStrings ["__DOTFILES_DIR__"] [dotfilesDir]
    (builtins.readFile ../../firefox/policies/policies.json);

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    # Wires the launcher's generic --tabs provider hook to the Firefox
    # native-messaging bridge (firefox_tab_switcher.lua's replacement).
    LAUNCHER_TABS_COMMAND = "${dotfilesDir}/helper_scripts/libexec/launcher/firefox-tabs";
  };

  # text-expander needs evdev ("input" group) and uinput ("uinput" group, enabled below) access; neither is granted by default.
  hardware.uinput.enable = true;
  # users.users.${primaryUser.name}.extraGroups would recurse into computing primaryUser itself; extend membership by name instead.
  users.groups.input.members = [primaryUser.name];
  users.groups.uinput.members = [primaryUser.name];

  systemd.user.services.text-expander = {
    description = "Text expansion daemon (evdev/uinput port of text_expander.lua)";
    wantedBy = ["default.target"];
    # notify-send is the only external command the script shells out to; dynamic triggers use Python's stdlib instead.
    path = [pkgs.libnotify];
    serviceConfig = {
      # Full store path: systemd user services get a minimal PATH without the Nix profile's bin dir.
      ExecStart = "${pythonWithEvdev}/bin/python3 ${dotfilesDir}/helper_scripts/libexec/desktop/text-expander";
      Restart = "on-failure";
    };
  };

  # Watches monitor hotplug/lid/resume and applies the best matching ~/.config/hyprmoncfg/profiles/ profile.
  systemd.user.services.hyprmoncfgd = {
    description = "hyprmoncfg monitor-profile daemon";
    wantedBy = ["default.target"];
    path = [config.programs.hyprland.package];
    serviceConfig = {
      ExecStart = "${pkgs.hyprmoncfg}/bin/hyprmoncfgd";
      Restart = "on-failure";
    };
  };
}
