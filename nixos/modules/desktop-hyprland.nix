# Shared across Linux hosts so the x86_64 host (task #4) can reuse it.
{
  pkgs,
  config,
  lib,
  ...
}: let
  # Derived from whichever user the host itself declares as isNormalUser,
  # rather than hardcoding a username in this shared module. Fails loudly
  # (not a silent alphabetical-first guess) if that single-normal-user
  # assumption is ever wrong for a host reusing this module.
  normalUsers = lib.filterAttrs (_: u: u.isNormalUser) config.users.users;
  primaryUser =
    if builtins.length (lib.attrNames normalUsers) == 1
    then lib.head (lib.attrValues normalUsers)
    else throw "desktop-hyprland.nix: expected exactly one isNormalUser account, found ${toString (builtins.length (lib.attrNames normalUsers))} (${toString (lib.attrNames normalUsers)})";
  dotfilesDir = "${primaryUser.home}/dotfiles";
  pythonWithEvdev = pkgs.python3.withPackages (ps: [ps.evdev]);

  # nixpkgs' pkgs.fira-code only ships the newer variable-font build
  # (FiraCode-VF.ttf, named instances FiraCodeRoman-Regular/Medium/...),
  # dropping the classic static per-weight release entirely -- no "Retina"
  # weight equivalent exists in it. macOS's setup/install-fonts.sh installs
  # that classic static release directly from GitHub instead, and kitty.conf/
  # the font-changer pickers pin the specific "FiraCode-Retina" weight from
  # it (a real, distinct weight, not just an alias for Regular -- confirmed
  # by inspecting the release zip's ttf/ folder). Fetching the exact same
  # release here keeps font-family/PostScript-name selection identical on
  # both platforms instead of picking nixpkgs' different default.
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

  # Secret Service backend for secret-tool (helper_scripts/bin/helpers/pass.sh).
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # powerprofilesctl; helper_scripts/bin/helpers/low-power-mode-toggle.sh
  services.power-profiles-daemon.enable = true;

  # org.freedesktop.UPower D-Bus service (battery/device info); separate
  # from power-profiles-daemon above. Used by Quickshell's native
  # Quickshell.Services.UPower module (plugins/bar/Power.qml).
  services.upower.enable = true;

  # bluetoothctl; helper_scripts/bin/helpers/tmux_bluetooth.sh
  hardware.bluetooth.enable = true;

  # Quickshell's native Quickshell.Networking module (plugins/bar/Network.qml)
  # only has a NetworkManager backend, so this replaces NixOS's default DHCP
  # network management. Chosen even though the current VM has one wired NIC
  # and no Wi-Fi hardware to exercise it with, because this config's actual
  # target is a laptop with Wi-Fi.
  networking.networkmanager.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Terminal configs ask for exact family/PostScript names, and the
  # nerd-fonts-patched builds rename both (confirmed via fc-list on the VM):
  # patched Fira Code ships as "FiraCode Nerd Font" (no space, "Nerd Font"
  # suffix), not the literal "Fira Code" ghostty's config asks for, nor the
  # "FiraCode-Retina" PostScript name kitty.conf matches on. So both the
  # nerd-patched (icon glyphs) and plain (name match) builds are needed for
  # jetbrains-mono/fira-code -- firaCodeStatic (defined above) instead of
  # nixpkgs' pkgs.fira-code, to match macOS's font exactly, "Retina" weight
  # included. nerd-fonts.symbols-only: the standalone "Symbols Nerd Font"
  # all three terminals reference for icon glyphs, not bundled with either
  # mono font.
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.symbols-only
    pkgs.jetbrains-mono
    firaCodeStatic
    # Rest of macOS's setup/install-fonts.sh list -- not referenced by any
    # terminal config right now, ported anyway per user request to keep
    # them available for manual/occasional use like on macOS.
    pkgs.input-fonts # Input Mono
    pkgs.noto-fonts # includes Noto Sans Mono
    pkgs.victor-mono
    pkgs.ibm-plex # includes IBM Plex Mono
    pkgs.iosevka
    pkgs.cascadia-code
  ];

  # Same firefox/policies/policies.json used on macOS (force-installs the
  # Firefox Bridge extension used by firefox_tab_switcher.lua, plus the rest
  # of the extension list). __DOTFILES_DIR__ is substituted here the same
  # way macOS's setup.sh does it with sed -- content stays authored in the
  # plain repo file, this just places it at /etc/firefox/policies/policies.json.
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

  # text_expander.lua's replacement (helper_scripts/libexec/desktop/text-expander):
  # reads raw keyboard events via evdev (needs "input" group for
  # /dev/input/event*) and injects replacements via a synthetic uinput
  # virtual keyboard (needs /dev/uinput, created by this module + "uinput"
  # group). Neither is granted by default.
  hardware.uinput.enable = true;
  # users.users.${primaryUser.name}.extraGroups would read config.users.users
  # (to compute primaryUser) while also contributing to it -- genuine
  # infinite recursion. Extending group membership by name instead only
  # reads primaryUser.name as a value, not as an attribute key.
  users.groups.input.members = [primaryUser.name];
  users.groups.uinput.members = [primaryUser.name];

  systemd.user.services.text-expander = {
    description = "Text expansion daemon (evdev/uinput port of text_expander.lua)";
    wantedBy = ["default.target"];
    # PATH: notify-send is the only external command the script still shells
    # out to (toggle on/off notification) -- same minimal-PATH problem as
    # ExecStart itself, just one level down via subprocess.run. The dynamic
    # triggers (@@ip, @@localip, etc.) use Python's own urllib/socket, not
    # curl/iproute2, specifically to avoid pulling in packages for this.
    path = [pkgs.libnotify];
    serviceConfig = {
      # Full store path instead of relying on env python3 -- systemd user
      # services get a minimal PATH that doesn't include the Nix profile's
      # bin dir (confirmed: "env: 'python3': No such file or directory").
      ExecStart = "${pythonWithEvdev}/bin/python3 ${dotfilesDir}/helper_scripts/libexec/desktop/text-expander";
      Restart = "on-failure";
    };
  };
}
