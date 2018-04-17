{ lib, writeText, callPackage, runCommand, nodejs-8_x, npmFetch }:
{ contextJson }:

with lib;
with builtins;
with (callPackage ./util.nix {});
with (callPackage ./context/dep-map.nix {});
let
  context = importJSON contextJson;
  fetch = self: super: let
    shouldFetch = hasAttrs [ "resolved" "integrity" ] super;
  in optionalAttrs shouldFetch {
    npmPackage = npmFetch { inherit (self) name version resolved integrity; };
  };

  extract = callPackage ./extract.nix {};

  augmentedContext = extendPackages context [ fetch extract ];

in writeText "context.json" (toJSON augmentedContext)
