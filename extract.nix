{ runCommand, lib, nodejs-8_x }:

self: super: let
  inherit (self) name drvName drvVersion;
in lib.optionalAttrs (!(super ? self) && super ? npmPackage) {
  extracted = runCommand "node-${drvName}-${drvVersion}" { inherit (super) npmPackage; buildInputs = [ nodejs-8_x ]; } ''
    export outPath="$out/lib/node_modules/${name}"
    mkdir -p $outPath
    tar xf $npmPackage --warning=no-unknown-keyword --directory $outPath --strip-components=1
    node ${./nix-bin.js} $outPath/package.json | xargs --max-args=3 --no-run-if-empty bash -c 'binfile=$(realpath $outPath/$3) ; chmod +x $binfile' _
  '';
}
