{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/desktop-hyprland.nix
  ];

  networking.hostName = "x86_64-generic";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = ["nix-command" "flakes"];

  users.users.erdembozkurt = {
    isNormalUser = true;
    extraGroups = ["wheel" "docker" "networkmanager"];
    shell = pkgs.zsh;
    initialPassword = "changeme";
    # No known SSH key for this host yet -- it isn't installed anywhere,
    # this config only needs to evaluate/build for task #4's CI check.
    # Add one here once it's actually deployed (see utm-aarch64's for the
    # pattern).
    openssh.authorizedKeys.keys = [];
  };
  programs.zsh.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    settings.PermitRootLogin = "no";
  };

  virtualisation.docker.enable = true;

  system.stateVersion = "24.05";
}
