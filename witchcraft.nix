{ pkgs, writeText, lib, callPackage, stdenv, runCommand, python, nodejs }:
{ contextJson, src }:

with lib;
with builtins;
with (callPackage ./util.nix {});
with (callPackage ./scriptlets.nix {});
with (callPackage ./context/dep-map.nix {});
let
  context = importJSON contextJson;

  extract = callPackage ./extract.nix {};

  augmentedContext = extendPackages context [ extract ];

in writeText "context.json" (toJSON augmentedContext)
