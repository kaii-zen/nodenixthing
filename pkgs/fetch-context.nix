{ lib, writeText, callPackage, runCommand, nodejs, npmFetch }:
{ context
, npmRc ? ""
}:

with lib;
with builtins;
with (callPackage ../lib {});
with (callPackage ../context.nix {});
let
  fetch = self: super: let
    shouldFetch = hasAttrs [ "resolved" "integrity" ] super;
  in optionalAttrs shouldFetch {
    npmPackage = npmFetch { inherit (self) name version resolved integrity npmRc; };
  };

  extract = callPackage ../extract.nix {};

  augmentedContext = extendPackages context [ fetch extract ];

in writeText "context.json" (toJSON augmentedContext)
