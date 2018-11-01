{ pkgs ? import <nixpkgs> {} }:

import ../.. {
  src = ./.;
}
