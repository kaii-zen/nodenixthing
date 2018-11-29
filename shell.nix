{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  buildInputs = [
    bashInteractive
    nodejs
    (callPackages ./pkgs {}).nodenixthing
  ];
}
