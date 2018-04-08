{ pkgs, closureInfo, writeReferencesToFile, stdenv, jq, python, writeText, makeWrapper, nodejs-8_x, callPackage, lib, runCommand }:
{ name, version, env, contextJson }:

with builtins;
with lib;
with (callPackage ./util.nix {});
with (callPackage ./scriptlets.nix {});
with (callPackage ./context/dep-map.nix {});
let
  context = importJSON contextJson;
  self = context.${name}.${version};

  inherit (self) drvName drvVersion path;

  dependenciesNoDev = removeDev context;
  selfAndNoDev = recursiveUpdate { ${name}.${version} = self; } dependenciesNoDev;

  bin = let
    paths = mapPackagesToList (_: _: {path,...}: builtins.toPath path) selfAndNoDev;
    rootPaths = map dirOf (paths ++ [ path ]);
    makeWrapperOpts = let
      env' = concatStringsSep " " (mapAttrsToList (name: value: ''
        --set ${name} "${value}"
      '') env);
    in ''
      --set NIX_JSON "$nixJson" --set NODE_OPTIONS "--require ${./nix-require.js}" ${env'}
    '';
  in runCommand "node-${drvName}-${drvVersion}-bin" {
    nativeBuildInputs = [ makeWrapper ];
    buildInputs = [ nodejs-8_x ];
    nixJson = toJSON selfAndNoDev;
    passAsFile = [ "nixJson" ];
  } ''
    export libpath=${path}/lib/node_modules/${name}
    export binpath=$out/bin
    export nixJson="$out/nix-support/nix.json"
    closureInfo=${closureInfo { inherit rootPaths; }};
    set -eo pipefail
    mkdir -p $binpath
    ${concatStrings (mapAttrsToList (bin: target: ''
      makeWrapper $(realpath $libpath/${target}) $out/bin/${bin} ${makeWrapperOpts}
    '') self.bin)}
    mkdir -p $out/nix-support
    cp $nixJsonPath $nixJson
    cp $closureInfo/registration $out/nix-path-registration
  '';

in bin
#  pkg = let
#    hasBins = self.bin != {};
#  in runCommand "node-${drvName}-${drvVersion}" {
#    buildInputs = optional hasBins bin ++ [ (writeReferencesToFile "${bin}/bin/hello") ];
#    propagatedBuildInputs = [ path ];
#  } (''
#    mkdir -p $out
#    cd $out
#    ln -s ${path}/ lib
#    echo $buildInputs > $out/refs
#  '' + optionalString hasBins ''
#    ln -s ${bin}/bin/ bin
#  '');
#in pkg
