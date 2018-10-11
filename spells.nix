{ pkgs, makeWrapper, writeText, lib, callPackage, stdenv, runCommand, python, nodejs-8_x, gcc }:
{ contextJson, env, npmPkgOpts, src }:

with lib;
with builtins;
with (callPackage ./util.nix {});
with (callPackage ./scriptlets.nix {});
with (callPackage ./context/dep-map.nix {});
let
  context = importJSON contextJson;

  genMeta = packageJson@{ contributors ? [] , description ? "" , homepage ? "", ...}:
  assert isList contributors; {
    meta = (optionalAttrs (packageJson ? contributors) {
      maintainers = contributors;
    }) // (optionalAttrs (packageJson ? description) {
      inherit description;
    }) // (optionalAttrs (packageJson ? homepage) {
      inherit homepage;
    });
  };

  installNodeModules = self: super: let
    inherit (super) name version shouldCompile shouldPrepare;
    needNodeModules = shouldCompile || shouldPrepare || super ? self;
    mkNodeModules = callPackage ./voodoo.nix {};
  in optionalAttrs needNodeModules {
    nodeModules = mkNodeModules {
      inherit name version;
      context = augmentedContext;
    };
  };

  addSrc = self: super: optionalAttrs (super ? self) {
    inherit src;
  };

  extract = callPackage ./extract.nix {};

  buildSelf = self: super: let
    inherit src;
    inherit (self) name version drvName drvVersion nodeModules;
    workDir = "~/src";
    supplementalBuildInputs = optionals (super ? buildInputs) super.buildInputs;
    npmPackage = stdenv.mkDerivation (env // {
      inherit src;
      dontStrip = true;
      name = "node-${drvName}-${drvVersion}.tgz";
      buildInputs = [ nodejs-8_x ] ++ supplementalBuildInputs;
      prePhases = [ "setHomePhase" ];
      setHomePhase = "export HOME=$TMPDIR";
      unpackPhase = ''
        ${copyDirectory src workDir}
        cd ${workDir}
      '';

      configurePhase = ''
        ln -s ${nodeModules}/lib/node_modules node_modules
          ${concatStrings (mapAttrsToList (name: value: ''
            npm set ${name} "${value}"
          '') npmPkgOpts)}
          '';

          buildPhase = ''
            npm pack
          '';

          installPhase = ''
            cp ${drvName}-${super.packageJson.version}.tgz $out
          '';
        });

    extracted = let
      dependenciesNoDev = removeDev augmentedContext;
      selfAndNoDev = mapPackages (_: _: attrs:
        if attrs ? self
        then { inherit (attrs) requires; }
        else { inherit (attrs) path; } //
          optionalAttrs (attrs ? packageJsonOverride) { inherit (attrs) packageJsonOverride; } //
          optionalAttrs (attrs ? requires) { inherit (attrs) requires; }) dependenciesNoDev;

      makeWrapperOpts = let
        env' = concatStringsSep " " (mapAttrsToList (name: value: ''--set ${name} "${value}"'') env);
      in ''--set NIX_JSON "$nixJson" --set NODE_OPTIONS "--require ${./nix-require.js}" ${env'}'';
    in stdenv.mkDerivation {
      name = "node-${drvName}-${drvVersion}";
      src = npmPackage;
      buildInputs = [ nodejs-8_x ];

      nativeBuildInputs = [ makeWrapper ];
      nixJson = toJSON selfAndNoDev;
      passAsFile = [ "nixJson" ];
      phases = [ "installPhase" "fixupPhase" ];
      installPhase = ''
        set -eo pipefail

        export libPath="$out/lib/node_modules/${name}"
        export binPath=$out/bin
        export nixJson="$out/nix-support/nix.json"

        mkdir -p $(dirname $nixJson)
        mkdir -p $libPath

        #cat $nodeModulesPath | xargs -n1 > $out/nix-support/srcs

        tar xf $src --warning=no-unknown-keyword --directory $libPath --strip-components=1
        ${concatStrings (mapAttrsToList (bin: target: ''
          mkdir -p $binPath
          target=$(realpath $libPath/${target})
          chmod +x $target
          makeWrapper $target $out/bin/${bin} ${makeWrapperOpts}
        '') self.bin)}
        cp $nixJsonPath $nixJson
      '';

      inherit (genMeta super.packageJson) meta;
    };
  in optionalAttrs (super ? self) {
    inherit extracted;
  };

  buildNative = self: super: let
    inherit (self) name drvName drvVersion shouldCompile nodeModules;
    supplementalBuildInputs = optionals (self ? buildInputs) (map (n: pkgs.${n}) self.buildInputs);
    supplementalPropagatedBuildInputs = optionals (self ? propagatedBuildInputs) (map (n: pkgs.${n}) self.propagatedBuildInputs);
    supplementalPatches = optionals (self ? patches) self.patches;
    darwinBuildInputs = with pkgs.darwin; optionals stdenv.isDarwin [ cctools dtrace apple_sdk.frameworks.CoreServices ];
  in {
    built = if shouldCompile then stdenv.mkDerivation {
      src = self.extracted;
      name = "${self.extracted.name}-${pkgs.system}";
      propagatedBuildInputs = supplementalPropagatedBuildInputs;
      buildInputs = [ nodejs-8_x python ] ++ darwinBuildInputs ++ supplementalBuildInputs;
      patches = supplementalPatches;
      phases = [ "installPhase" "fixupPhase" ];
      installPhase = ''
        ${copyDirectory "$src" "$out"}
        outPath="$out/lib/node_modules/${name}"
        cd $outPath
        if [[ -d node_modules ]]; then
          mv node_modules .node_modules
        fi
        ln -s ${nodeModules}/lib/node_modules node_modules
        export PYTHON=${python}/bin/python
        export HOME=$TMPDIR
        export INCLUDE_PATH=${nodejs-8_x}/include/node
        export C_INCLUDE_PATH=$INCLUDE_PATH
        export CPLUS_INCLUDE_PATH=$INCLUDE_PATH
        export npm_config_nodedir=$INCLUDE_PATH
        for i in ''${patches:-}; do
          cat $i | patch -p1
        done
        npm run install --build-from-source
        rm node_modules
        if [[ -d .node_modules ]]; then
          mv .node_modules node_modules
        fi
        find -regextype posix-extended -regex '.*\.(o|mk)' -delete
      '';
      inherit (genMeta super.packageJson) meta;
    } else self.extracted;
  };

  setPath = self: super: {
    path = if isString self.built then toPath self.built else self.built;
  };

  augmentedContext = extendPackages context [ installNodeModules extract buildNative buildSelf setPath addSrc ];

in augmentedContext
