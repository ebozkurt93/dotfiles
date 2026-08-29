# Not yet in nixpkgs (open PR: https://github.com/NixOS/nixpkgs/pull/552223, pkgs/by-name/hy/hyprmoncfg).
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule (finalAttrs: {
  pname = "hyprmoncfg";
  version = "1.16.1";

  src = fetchFromGitHub {
    owner = "crmne";
    repo = "hyprmoncfg";
    tag = "v${finalAttrs.version}";
    hash = "sha256-7wyghP1S7vauC2yJozaEg8ZfPgUNdgtaI4vq5XcTqGE=";
  };

  vendorHash = "sha256-gQbjvdKtO0hCXrs9RnWo1s0YeHf5W9t+8AgS2ELXlPo=";

  subPackages = ["cmd/hyprmoncfg" "cmd/hyprmoncfgd"];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/crmne/hyprmoncfg/internal/buildinfo.Version=${finalAttrs.version}"
  ];

  doCheck = false;

  meta = {
    description = "Visual multi-monitor layout editor and automatic profile switcher for Hyprland";
    homepage = "https://hyprmoncfg.dev/";
    license = lib.licenses.mit;
    mainProgram = "hyprmoncfg";
  };
})
