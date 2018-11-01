let
  pkgs = import <nixpkgs> {
    overlays = [(self: super: {
      inherit (nur.repos.kreisys) nodejs-8_x;
    })];
  };

  nur = import (builtins.fetchGit https://github.com/nix-community/NUR) {
    inherit pkgs;
  };

  home = builtins.getEnv "HOME";
  idRsa = builtins.readFile "${home}/.ssh/id_rsa";
  npmRc = builtins.readFile "${home}/.npmRc";

in import ../../default.nix {
  inherit pkgs;
  src = pkgs.lib.cleanSource ./.;
  inherit idRsa npmRc;
}
