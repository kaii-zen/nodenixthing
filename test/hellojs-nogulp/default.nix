{ pkgs ? import <nixpkgs> {} }:

import ../.. {
  src = builtins.path {
    path = ./.;
    filter = path: type: type != "symlink" && ! builtins.elem (baseNameOf path) [ ".git" "node_modules" ];
  };

  npmPkgOpts = {
    "hello:meow" = "rawr";
  };
}
