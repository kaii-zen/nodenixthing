{ pkgs ? import <nixpkgs> {} }:

import ../.. {
  inherit pkgs;
  src = pkgs.lib.cleanSource ./.;

  npmPkgOpts = {
    "hello:meow" = "woof";
  };

  check = ''
    hello
  '';
}
