{ pkgs ? import <nixpkgs> {} }:

import ../.. {
  src = pkgs.lib.cleanSource ./.;

  npmPkgOpts = {
    "hello:meow" = "rawr";
  };

  check = ''
    hello
  '';
}
