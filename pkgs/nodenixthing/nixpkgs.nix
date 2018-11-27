{ system ? builtins.currentSystem }:

with builtins;

let
  importJSON = file: fromJSON (readFile file);

  nixpkgs = builtins.fetchGit {
    inherit (importJSON ./nixpkgs.json) url rev;
  };

  nodenixthing = builtins.fetchGit {
    inherit (importJSON ./nodenixthing.json) url rev;
  };
in import nixpkgs {
  inherit system;
  overlays = [ (_: pkgs: {
    inherit (pkgs.callPackages "${nodenixthing}/pkgs" {}) nodenixthing;
    nodejs = pkgs.nodejs-10_x;
    # Override additional packages here if necessary
    # ...
  })];
}
