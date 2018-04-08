{ lib, writeText, callPackage, runCommand, nodejs-8_x }:
{ contextJson }:

with lib;
with builtins;
with (callPackage ./util.nix {});
with (callPackage ./context/dep-map.nix {});
let
  context = importJSON contextJson;
  npmFetch = callPackage ./npm/fetch.nix {};
  fetch = self: super: let
    shouldFetch = hasAttrs [ "resolved" "integrity" ] super;
  in optionalAttrs shouldFetch {
    npmPackage = npmFetch { inherit (self) name version resolved integrity; };
  };

  extract = self: super: let
    inherit (self) name drvName drvVersion;
  in optionalAttrs (super ? npmPackage) {
    extracted = runCommand "node-${drvName}-${drvVersion}" { inherit (super) npmPackage; buildInputs = [ nodejs-8_x ]; } ''
      export outPath="$out/lib/node_modules/${name}"
      mkdir -p $outPath
      tar xf $npmPackage --warning=no-unknown-keyword --directory $outPath --strip-components=1
      node ${./nix-bin.js} $outPath/package.json | xargs --max-args=3 --no-run-if-empty bash -c 'binfile=$(realpath $outPath/$3) ; chmod +x $binfile' _
    '';
  };

  augmentedContext = extendPackages context [ fetch extract ];

in writeText "context.json" (toJSON augmentedContext)
