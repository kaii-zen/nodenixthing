{ nodenixthingRoot
, nixpkgs
, pkgs                ? import nixpkgs {}
, nodenixthingPkgs    ? pkgs.callPackages "${nodenixthingRoot}/pkgs" {}
, src                 ? builtins.getEnv "PWD"}:

with pkgs.lib;

let context = nodenixthingPkgs.mkNpmPackageContext {
    package = importJSON "${src}/package.json";
    lock    = importJSON "${src}/npm-shrinkwrap.json";
  };
in context
