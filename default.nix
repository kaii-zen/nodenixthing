{ pkgs ? import nixpkgs { inherit system; }
, nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
, npmShrinkwrapJson ? "npm-shrinkwrap.json"
, npmPackageJson ? "package.json"
, supplemental ? {}
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

  mkContext = callPackage ./context {};
  doMagic = callPackage ./magic.nix {};
  doWitchcraft = callPackage ./witchcraft.nix {};
  castSpells = callPackage ./spells.nix {};
  makeUnicorn = callPackage ./unicorns.nix {};

  contextJson = mkContext { inherit package lock supplemental src; };
  fetchedContextJson = doMagic { inherit contextJson; };
  processedContextJson = doWitchcraft { contextJson = fetchedContextJson; };
  builtContextJson = castSpells { contextJson = processedContextJson; inherit env; };
  #unicorn = makeUnicorn { contextJson = builtContextJson; inherit name version env; };
in builtContextJson.${name}.${version}.path
