# Not in nixpkgs. Derivation adapted from upstream's own package.nix
# (https://github.com/WhySoBad/hyprland-preview-share-picker/blob/v0.2.1/package.nix).
{
  lib,
  glib,
  gtk4,
  gtk4-layer-shell,
  pkg-config,
  rustPlatform,
  fetchFromGitHub,
}: let
  src = fetchFromGitHub {
    owner = "WhySoBad";
    repo = "hyprland-preview-share-picker";
    tag = "v0.2.1";
    fetchSubmodules = true; # lib/hyprland-protocols
    hash = "sha256-Zztb0soSN/NynWnBIGPuUNRKt2xSx/+f+QpYIPRyRdc=";
  };
in
  rustPlatform.buildRustPackage {
    pname = "hyprland-preview-share-picker";
    version = "0.2.1";

    inherit src;

    nativeBuildInputs = [pkg-config];
    buildInputs = [glib gtk4 gtk4-layer-shell];

    strictDeps = true;
    cargoLock.lockFile = "${src}/Cargo.lock";

    meta = {
      description = "Alternative share picker for Hyprland with window and monitor previews";
      homepage = "https://github.com/WhySoBad/hyprland-preview-share-picker";
      license = lib.licenses.mit;
      mainProgram = "hyprland-preview-share-picker";
    };
  }
