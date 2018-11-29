{ nodenixthingRoot
, nixpkgs
, pkgs                ? import nixpkgs {}
, nodenixthingPkgs    ? pkgs.callPackages "${nodenixthingRoot}/pkgs" {}
, src                 ? builtins.getEnv "PWD"}:

with pkgs.lib;

let
  hasSupplemental = builtins.pathExists "${src}/supplemental.nix";

  context = nodenixthingPkgs.mkNpmPackageContext {
    package      = importJSON "${src}/package.json";
    lock         = importJSON "${src}/npm-shrinkwrap.json";
    supplemental = optionalAttrs hasSupplemental (import "${src}/supplemental.nix" { inherit pkgs; });
  };
in context
