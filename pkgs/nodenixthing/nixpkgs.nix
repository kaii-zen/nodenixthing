with builtins;

{ system ? currentSystem }: let
  importJSON = file: fromJSON (readFile file);

  nixpkgs = fetchGit {
    inherit (importJSON ./nixpkgs.json) url rev;
  };

  nodenixthing = fetchGit {
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
