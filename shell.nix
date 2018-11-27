{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  buildInputs = [
    nodejs
    (callPackages ./pkgs {}).nodenixthing
  ];
}
