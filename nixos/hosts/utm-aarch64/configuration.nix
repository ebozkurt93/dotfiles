{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/desktop-hyprland.nix
  ];

  networking.hostName = "utm-aarch64";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = ["nix-command" "flakes"];

  users.users.erdembozkurt = {
    isNormalUser = true;
    extraGroups = ["wheel" "docker"];
    shell = pkgs.zsh;
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICenmRB08ozm1dD8OMfLXab8UvrthP64KOkQsvPAv+tU nixos-utm-vm"
    ];
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
