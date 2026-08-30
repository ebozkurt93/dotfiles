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

  xdg.mime.enable = true;
  xdg.mime.defaultApplications = {
    "image/png" = "imv.desktop";
    "image/jpeg" = "imv.desktop";
    "image/gif" = "imv.desktop";
    "image/webp" = "imv.desktop";
    "image/bmp" = "imv.desktop";
    "image/svg+xml" = "imv.desktop";
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

  # bluetoothctl; helper_scripts/bin/helpers/tmux_bluetooth.sh
  hardware.bluetooth.enable = true;

  # Quickshell's Networking module (plugins/bar/Network.qml) only has a NetworkManager backend.
  networking.networkmanager.enable = true;

  # services.openssh.openFirewall defaults to true, so SSH stays reachable on hosts that enable it.
  networking.firewall.enable = true;
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
  ];

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
