# Shared across Linux hosts so the x86_64 host (task #4) can reuse it.
{pkgs, ...}: {
  programs.hyprland.enable = true;
  security.pam.services.dotfiles-lock = {};

  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-hyprland];
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
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

  # bluetoothctl; helper_scripts/bin/helpers/tmux_bluetooth.sh
  hardware.bluetooth.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  fonts.packages = [pkgs.nerd-fonts.jetbrains-mono];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };
}
