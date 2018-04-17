{ pkgs ? import <nixpkgs> {}
, npmShrinkwrapJson ? src + "/npm-shrinkwrap.json"
, npmPackageJson ? src + "/package.json"
, supplemental ? {}
, idRsa ? ""
, npmRc ? ""
, npmPkgOpts ? {}
, env ? {}
, src }:

with builtins;
with pkgs;
with pkgs.lib;
with (callPackage ./util.nix {});
let
  package = importJSON npmPackageJson;
  lock    = importJSON npmShrinkwrapJson;
  inherit (package) name version;

  npmFetch = callPackage ./npm/fetch.nix { inherit idRsa npmRc; };

  mkContext = callPackage ./context {};
  doMagic = callPackage ./magic.nix { inherit npmFetch; };
  doWitchcraft = callPackage ./witchcraft.nix {};
  castSpells = callPackage ./spells.nix {};
  makeUnicorn = callPackage ./unicorns.nix {};

  contextJson = mkContext { inherit package lock supplemental src; };
  fetchedContextJson = doMagic { inherit contextJson; };
  processedContextJson = doWitchcraft { contextJson = fetchedContextJson; fallback = builtins.dirName npmPackageJson; };
  builtContext = castSpells { contextJson = processedContextJson; inherit env npmPkgOpts; };
in builtContext.${name}.${version}.path
