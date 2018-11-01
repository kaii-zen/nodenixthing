{ pkgs ? import <nixpkgs> {} }:

import ../.. {
  inherit pkgs;
  src = ./.;
  npmPkgOpts = {
    "hello:meow" = "woof";
  };
}
