{ pkgs ? import <nixpkgs> {}
, supplemental ? {}
, idRsa ? ""
, npmRc ? ""
, npmPkgOpts ? {}
, env ? {}
, srcPath
, srcFilter ? path: type: type != "symlink" && ! builtins.elem (baseNameOf path) [ ".git" "node_modules" ]
}:

with builtins;
with pkgs;
with pkgs.lib;
with (callPackage ./util.nix {});
let
  src = {
    outPath = builtins.path {
      path = srcPath;
      filter = srcFilter;
    };

    packageJson = srcPath + "/package.json";
    npmShrinkwrap = srcPath + "/npm-shrinkwrap.json";
  };

  package = importJSON src.packageJson;
  lock    = importJSON src.npmShrinkwrap;

  inherit (package) name version;

  npmFetch = callPackage ./npm/fetch.nix { inherit idRsa npmRc; };

  mkContext = callPackage ./context {};
  doMagic = callPackage ./magic.nix { inherit npmFetch; };
  doWitchcraft = callPackage ./witchcraft.nix {};
  castSpells = callPackage ./spells.nix {};
  makeUnicorn = callPackage ./unicorns.nix {};

  contextJson = mkContext { inherit package lock supplemental; };
  fetchedContextJson = doMagic { inherit contextJson; };
  processedContextJson = doWitchcraft { contextJson = fetchedContextJson; src = srcPath; };
  builtContext = castSpells { contextJson = processedContextJson; inherit env npmPkgOpts; src = srcPath; };
in builtContext.${name}.${version}.path
