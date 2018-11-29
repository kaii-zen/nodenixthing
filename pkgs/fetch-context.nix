{ lib, writeText, callPackage, runCommand, nodejs, npmFetch }:
{ context
, npmRc ? ""
}:

with lib;
with builtins;
with (callPackage ../lib {});
with (callPackage ./make-context/dep-map.nix {});
let
  fetch = self: super: let
    shouldFetch = hasAttrs [ "resolved" "integrity" ] super;
  in optionalAttrs shouldFetch {
    npmPackage = npmFetch { inherit (self) name version resolved integrity npmRc; };
  };

  #extract = callPackage ./extract.nix {};

  #augmentedContext = extendPackages context [ fetch extract ];
  augmentedContext = extendPackages context [ fetch ];

in writeText "context.json" (toJSON augmentedContext)
