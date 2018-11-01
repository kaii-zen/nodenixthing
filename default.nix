{ pkgs ? import <nixpkgs> {}
, supplemental ? {}
, idRsa ? ""
, npmRc ? ""
, npmPkgOpts ? {}
, preBuild ? ""
, check ? "true"
, env ? {}
, src
}:

with builtins;
with pkgs;
with pkgs.lib;
with (callPackage ./util.nix {});
let
  package = importJSON "${src}/package.json";
  lock    = importJSON "${src}/npm-shrinkwrap.json";

  inherit (package) name version;

  npmFetch = callPackage ./npm/fetch.nix { inherit idRsa npmRc; };

  mkContext = callPackage ./context {};
  doMagic = callPackage ./magic.nix { inherit npmFetch; };
  doWitchcraft = callPackage ./witchcraft.nix {};
  doKabala = callPackage ./kabala.nix {};
  castSpells = callPackage ./spells.nix {};
  makeUnicorn = callPackage ./unicorns.nix {};

  context = mkContext { inherit package lock supplemental; };
  fetchedContextJson = doMagic { inherit context; };
  extractedContextJson = doWitchcraft { contextJson = fetchedContextJson; inherit src; };
  processedContextJson = doKabala { contextJson = extractedContextJson; inherit src; };
  builtContext = castSpells { contextJson = processedContextJson; inherit env npmPkgOpts src preBuild check; };
in {
  nix = builtContext.${name}.${version}.path;
  npm = builtContext.${name}.${version}.npmPackage;
}
