{ pkgs, stdenv, python, writeText, makeWrapper, nodejs-8_x, callPackage, lib, runCommand }:
{ depMap, npmPackage }:

with builtins;
with lib;
with (callPackage ./util.nix {});
with (callPackage ./scriptlets.nix {});
with (callPackage ./context/dep-map.nix {});
let
  dependencies = getDependencies npmPackage.unfilteredSrc depMap name version;

  json = let
    self = { ${name}.${version} = depMap.${name}.${version}; };
    dependenciesNoDev = removeDev dependencies;
    selfAndNoDev = recursiveUpdate self dependenciesNoDev;
  in optionalString (!dependency) (toJSON selfAndNoDev);

  name = npmPackage.pname;
  inherit (npmPackage) version;

  fixedName = replaceStrings [ "@" "/" ] [ "" "-" ] name;
  fixedVersion = let
    matchGit = match ".*#(.*)" version;
  in if matchGit == null then version else assert length matchGit == 1; head matchGit;

  getNpmPackage = callPackage ./npm/get.nix {} npmPackage.unfilteredSrc;

  src = getNpmPackage { inherit name version depMap npmPackage; };
  data = depMap.${name}.${version};

  # Boolean - true if we are the main package being built, false if we're a dependency.
  dependency = notxy hasAttr "self" data;
  resolved = data ? resolved;

  makeWrapperOpts = optionalString (!dependency)
    ''--set NIX_JSON "${writeText "node-${name}-${version}-nix.json" json}" --set NODE_OPTIONS "--require ${./nix-require.js}"'';

  libGeneric = stdenv.mkDerivation {
    inherit version src;
    pname = name;
    name = "node-${fixedName}-${fixedVersion}-lib";
    buildInputs = [ nodejs-8_x ];
    dontStrip = true;
    phases = [ "installPhase" "fixupPhase" ];
    installPhase = ''
      export libpath=$out/lib/node_modules/${name}
      mkdir -p $libpath
      tar xf $src --warning=no-unknown-keyword --directory $libpath --strip-components=1
      node ${./nix-bin.js} $libpath/package.json | xargs --max-args=3 --no-run-if-empty bash -c 'binfile=$(realpath $libpath/$3) ; chmod +x $binfile' _
    '';
  };

  libNative = let
    src = "${libGeneric}/lib/node_modules/${name}";
    packageJson = importJSON "${src}/package.json";
    npmScripts = optionalAttrs (packageJson ? scripts) packageJson.scripts;
    hasInstallScript = npmScripts ? install;
    hasBindingGyp = hasAttr "binding.gyp" (readDir src);
    shouldDoNpmRunInstall = hasInstallScript || hasBindingGyp;
    mkNodeModules = callPackage ./npm/install.nix {} depMap;
    nodeModules = mkNodeModules { inherit src name version; };
  in if shouldDoNpmRunInstall then stdenv.mkDerivation {
    inherit version;
    src = libGeneric;
    pname = name;
    name = "node-${fixedName}-${fixedVersion}-lib-${currentSystem}";
    buildInputs = [ nodejs-8_x nodeModules ] ++ optionals (data ? buildInputs) (map (n: pkgs.${n}) data.buildInputs);
    phases = [ "installPhase" "fixupPhase" ];
    installPhase = ''
      ${copyDirectory "$src" "$out"}
      cd $out/lib/node_modules/${name}
      rm -rf node_modules
      ln -s ${nodeModules}/node_modules node_modules
      export PYTHON=${python}/bin/python
      export HOME=$TMPDIR
      npm run install
      rm node_modules
    '';
  } else {};

  # Prefer libNative
  lib = if isDerivation libNative then libNative else libGeneric;

  bin = runCommand "node-${fixedName}-${fixedVersion}-bin" {
    inherit version;
    pname = name;
    nativeBuildInputs = [ makeWrapper ];
    buildInputs = [ nodejs-8_x lib ];
  } ''
    export libpath=${lib}/lib/node_modules/${name}
    export binpath=$out/bin
    set -eo pipefail
    mkdir -p $binpath
    export -f makeWrapper assertExecutable die
    node ${./nix-bin.js} $libpath/package.json | xargs --max-args=3 --no-run-if-empty bash -c 'binfile=$(realpath $libpath/$3) ; makeWrapper $binfile $binpath/$2 ${makeWrapperOpts}' _
  '';

  pkg = let
    packageJson = importJSON "${libGeneric}/lib/node_modules/${name}/package.json";
    hasBins = packageJson ? bin;
  in runCommand "node-${fixedName}-${fixedVersion}" {
    inherit version;
    pname = name;
    buildInputs = [ lib ] ++ optional hasBins bin;
  } (''
    mkdir -p $out
    cd $out

    ln -s ${lib}/lib lib
  '' + optionalString hasBins ''
    ln -s ${bin}/bin bin
  '');
in pkg
