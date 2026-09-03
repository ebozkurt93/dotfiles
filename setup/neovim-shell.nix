{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/2dcd9c55e8914017226f5948ac22c53872a13ee2.tar.gz") {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    bash
    ninja
    cmake
    gettext
    curl
  ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
    libiconv-darwin
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    patchelf
  ];
}
