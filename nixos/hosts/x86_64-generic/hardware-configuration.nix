# Placeholder -- this host isn't installed on real hardware yet (task #7,
# deferred until both VMs work end to end). Generic UEFI/ext4 x86_64 kernel
# modules and dummy disk UUIDs, good enough for this to evaluate/build for
# task #4's CI check. Replace entirely with the real
# `nixos-generate-config --root /mnt --show-hardware-config` output once
# this actually gets installed on the physical machine.
{
  lib,
  ...
}: {
  imports = [];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usb_storage" "sd_mod" "sr_mod" "nvme"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
