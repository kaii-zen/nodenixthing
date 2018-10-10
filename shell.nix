{ pkgs ? import <nixpkgs> {} }:

let
  nur = import (builtins.fetchGit https://github.com/nix-community/NUR) {
    inherit pkgs;
  };

in pkgs.mkShell {
  buildInputs = [ nur.repos.kreisys.nodejs-8_x ];
}
