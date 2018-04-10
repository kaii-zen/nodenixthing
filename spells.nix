{ pkgs, makeWrapper, writeText, lib, callPackage, stdenv, runCommand, python, nodejs-8_x }:
{ contextJson, env }:

with lib;
with builtins;
with (callPackage ./util.nix {});
with (callPackage ./scriptlets.nix {});
with (callPackage ./context/dep-map.nix {});
let
  context = importJSON contextJson;

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

  extract = self: super: let
    inherit (self) name drvName drvVersion;
  in optionalAttrs (!(super ? self) && super ? npmPackage) {
    extracted = runCommand "node-${drvName}-${drvVersion}" { inherit (super) npmPackage; buildInputs = [ nodejs-8_x ]; } ''
      export outPath="$out/lib/node_modules/${name}"
      mkdir -p $outPath
      tar xf $npmPackage --warning=no-unknown-keyword --directory $outPath --strip-components=1
      node ${./nix-bin.js} $outPath/package.json | xargs --max-args=3 --no-run-if-empty bash -c 'binfile=$(realpath $outPath/$3) ; chmod +x $binfile' _
    '';
  };

  buildSelf = self: super: let
    inherit (self) src name version drvName drvVersion nodeModules;
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
    };
  in optionalAttrs (super ? src) {
    inherit extracted;
  };

  buildNative = self: super: let
    inherit (self) name drvName drvVersion shouldCompile nodeModules;
    supplementalBuildInputs = optionals (self ? buildInputs) (map (n: pkgs.${n}) self.buildInputs);
    supplementalPropagatedBuildInputs = optionals (self ? propagatedBuildInputs) (map (n: pkgs.${n}) self.propagatedBuildInputs);
  in {
    built = if shouldCompile then stdenv.mkDerivation {
      src = self.extracted;
      name = "${self.extracted.name}-${builtins.currentSystem}";
      propagatedBuildInputs = supplementalPropagatedBuildInputs;
      buildInputs = [ nodejs-8_x python ] ++ supplementalBuildInputs;
      phases = [ "installPhase" "fixupPhase" ];
      installPhase = ''
        ${copyDirectory "$src" "$out"}
        outPath="$out/lib/node_modules/${name}"
        cd $outPath
        rm -rf node_modules
        ln -s ${nodeModules}/lib/node_modules node_modules
        export PYTHON=${python}/bin/python
        export HOME=$TMPDIR
        npm run install
        rm node_modules
        find -regextype posix-extended -regex '.*\.(o|mk)' -delete
      '';
    } else self.extracted;
  };

  setPath = self: super: {
    #path = trace "PATH IS ${typeOf self.built}" self.built;
    #path = toPath self.built;
    path = if isString self.built then toPath self.built else self.built;
  };

  augmentedContext = extendPackages context [ installNodeModules extract buildNative buildSelf setPath ];

in augmentedContext
