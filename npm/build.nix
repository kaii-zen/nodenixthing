{ lib, nodejs, callPackage, stdenv, parallel }:
{ src, depMap }:

with lib;
with builtins;
with (callPackage ../scriptlets.nix {});
let
  inherit (importJSON "${src}/package.json") name version;
  workDir = "~/src";
  mkNodeModules = callPackage ./install.nix {} depMap;
  nodeModules = mkNodeModules { inherit src name version; };
  filteredSrc = filterSource (path: type: type != "symlink" && ! elem (baseNameOf path) [ ".git" "node_modules" ]) src;
in stdenv.mkDerivation {
  inherit version;
  src = filteredSrc;
  passthru = {
    unfilteredSrc = src;
  };
  dontStrip = true;
  pname = name;
  name = "node-${name}-${version}.tgz";
  nativeBuildInputs = [ parallel ];
  buildInputs = [ nodejs ];
  prePhases = [ "setHomePhase" ];
  setHomePhase = "export HOME=$TMPDIR";
  unpackPhase = ''
    ${copyDirectory src workDir}
    cd ${workDir}
  '';

  configurePhase = ''
    ln -s ${nodeModules}/node_modules node_modules
  '';

  buildPhase = ''
    npm pack
  '';

  installPhase = ''
    cp ${name}-${version}.tgz $out
  '';
}
