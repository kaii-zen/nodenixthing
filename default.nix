{ pkgs ? import <nixpkgs> {}
, npmShrinkwrapJson ? "npm-shrinkwrap.json"
, npmPackageJson ? "package.json"
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
  package = importJSON "${src}/${npmPackageJson}";
  lock    = importJSON "${src}/${npmShrinkwrapJson}";
  inherit (package) name version;

  npmFetch = callPackage ./npm/fetch.nix { inherit idRsa npmRc; };

  mkContext = callPackage ./context {};
  doMagic = callPackage ./magic.nix { inherit npmFetch; };
  doWitchcraft = callPackage ./witchcraft.nix {};
  castSpells = callPackage ./spells.nix {};
  makeUnicorn = callPackage ./unicorns.nix {};

  contextJson = mkContext { inherit package lock supplemental src; };
  fetchedContextJson = doMagic { inherit contextJson; };
  processedContextJson = doWitchcraft { contextJson = fetchedContextJson; };
  builtContext = castSpells { contextJson = processedContextJson; inherit env npmPkgOpts; };
in builtContext.${name}.${version}.path
