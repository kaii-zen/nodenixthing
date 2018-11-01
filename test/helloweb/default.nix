{ pkgs ? import <nixpkgs> {} }:

import ../.. {
  src = pkgs.lib.cleanSource ./.;
}
