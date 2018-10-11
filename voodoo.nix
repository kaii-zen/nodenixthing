{ lib, writeText, callPackage, runCommand, nodejs-8_x }:
{ name, version, context }:

with lib;
with (callPackage ./scriptlets.nix {});
with (callPackage ./context/dep-map.nix {});
with (callPackage ./util.nix {});
let
  self = context.${name}.${version};
  inherit (self) drvName drvVersion;

  requires = optionalAttrs (self ? requires) self.requires;

  topLevelDependencies = requires;

  allModulesDir = "node_modules/.all";

  mkCopyPackageScriptlet = name: version: attrs: ''
    export moduleDir="$outPath/${allModulesDir}/${name}/${version}/node_modules/${name}"
    mkdir -p $moduleDir
    # hack for @scoped/packages
    rmdir $moduleDir
    ${copyDirectory "${attrs.path}/lib/node_modules/${name}" "$moduleDir"}
  '';

  mkUntarPackageScriptlet = name: version: attrs: ''
    export moduleDir="$outPath/${allModulesDir}/${name}/${version}/node_modules/${name}"
    mkdir -p $moduleDir
    tar xf ${attrs.npmPackage} --warning=no-unknown-keyword --directory=$moduleDir --strip-components=1
  '';

  linkDependency = name: version: ''
    target=$outPath/${allModulesDir}/${name}/${version}/node_modules/${name}

    if ! [[ -d ${name} ]]; then
      mkdir -p ${name}
      rmdir ${name}
      ln -s $target ${name}
    fi
  '';

  mkLinkPackageScriptlet = name: version: {requires ? {}, ...}: ''
    cd $outPath/${allModulesDir}/${name}/${version}/node_modules
    ${concatStrings (mapAttrsToList linkDependency requires)}
  '';

  mkLinkAllBinsScriptlet = name: version: _: let
    nodeModulesPath = "$outPath/${allModulesDir}/${name}/${version}/node_modules";
    binPath = "${nodeModulesPath}/${name}/node_modules/.bin";
  in ''
    find -L ${nodeModulesPath}/ -mindepth 2 -maxdepth 2 -name package.json -exec ${nodejs-8_x}/bin/node ${./nix-bin.js} {} \; | \
      xargs --max-args=3 --no-run-if-empty bash -c '[[ $1 == ${name} ]] || (mkdir -p ${binPath} ; ln -s $(readlink -f ${nodeModulesPath}/$1/$3) ${binPath}/$2)' _
  '';

  mkScript = let
    dependencies = dependenciesFor context name version;
  in { scriptletGenerator }: mkParallelScript (mapPackagesToList scriptletGenerator dependencies);

  copyAllDeps   = mkScript { scriptletGenerator = mkCopyPackageScriptlet; };
  untarAllDeps  = mkScript { scriptletGenerator = mkUntarPackageScriptlet; };
  linkAllDeps   = mkScript { scriptletGenerator = mkLinkPackageScriptlet; };
  linkAllBins   = mkScript { scriptletGenerator = mkLinkAllBinsScriptlet; };

  linkOwnDeps = ''
    mkdir -p $outPath/${allModulesDir}
    cd $outPath/${allModulesDir}
    cd ..
    ${concatStrings (mapAttrsToList linkDependency topLevelDependencies)}
  '';

  linkOwnBins = let
    nodeModulesPath = "$(realpath $outPath/${allModulesDir}/..)";
    binPath = "${nodeModulesPath}/.bin";
  in ''
    find -L ${nodeModulesPath}/ -mindepth 2 -maxdepth 2 -name package.json -exec ${nodejs-8_x}/bin/node ${./nix-bin.js} {} \; | \
      xargs --max-args=3 --no-run-if-empty bash -c '(mkdir -p ${binPath} ; ln -s $(readlink -f ${nodeModulesPath}/$1/$3) ${binPath}/$2)' _
  '';

  handlePeers = let
    script = mkPeerScriptFor { inherit name version; path = "$(realpath $outPath/${allModulesDir}/../..)"; };

    mkPeerScriptFor = { name, version, seen ? [], upperDeps ? {}, depth ? 0, path ? "$outPath/${allModulesDir}/${name}/${version}", prevPath ? null, prevPeerResolutionString ? null }: let
      self = getFromContext name version;
      requires = getRequires self;
      deps = requires // peerResolution;
      indent = str: let
        lines = splitString "\n" str;
        indentLine = line: let
          lineLength = stringLength line;
        in fixedWidthString (depth + lineLength) " " line;
        indentedLines = map indentLine lines;
      in concatStringsSep "\n" indentedLines;

      getFromContext = name: version: context.${name}.${version} // { inherit name version; };
      getRequires = { requires ? {}, ... }: requires;
      getPeers = { peerDependencies ? {}, ... }: attrNames peerDependencies;

      # => [ "@context/peerA", "peerB" ]
      peers = getPeers self.packageJson;
      # => "@context/peerA, peerB"
      peersStr = concatStringsSep ", " peers;
      # => { "@context/peerA" = "peerAVersion"; peerB = "peerBVersion"; }
      peerResolution = genAttrs peers (name: upperDeps.${name});
      # => [ "@context!peerA@peerAVersion" "peerB@peerBVersion" ]
      peerResolutionList = mapAttrsToList (name: version: "${replaceStrings [ "/" ] [ "!" ] name}@${version}") peerResolution;
      # => "@context!peerA@peerAVersion+peerB@peerBVersion"
      peerResolutionString = concatStringsSep "+" peerResolutionList;

      countPeersRecursively = { name, version, seen ? []}: let
        self = getFromContext name version;
        requires = getRequires self;
        myPeerCount = length (getPeers self.packageJson);
        myDependents'PeerCounts = mapAttrsToList (name: version: countPeersRecursively {
          inherit name version;
          seen = appendSeen {
            inherit (self) name version;
            inherit seen;
          };
        }) (filterSeen seen requires);
      in foldl (res: n: res + n) myPeerCount myDependents'PeerCounts;

      # => 2
      ownPeerCount = length peers;
      recursivePeerCount = countPeersRecursively { inherit name version; };

      havePeers = recursivePeerCount > 0;

      selfHead = optionalString havePeers (indent ''
        # ${name} ${version} (peerCount: ${toString ownPeerCount}/${toString recursivePeerCount}) (${peerResolutionString})
        if ! [[ -d ${path}/${peerResolutionString} ]]; then
          mkdir -p ${path}/${peerResolutionString}
          cp -a ${path}/node_modules ${path}/${peerResolutionString}/node_modules
          ${concatStrings (mapAttrsToList (n: v: (indent ''
          rm -f ${path}/${peerResolutionString}/node_modules/${n}
          mkdir -p ${path}/${peerResolutionString}/node_modules/${n}
          rmdir ${path}/${peerResolutionString}/node_modules/${n}
          ln -s $outPath/${allModulesDir}/${n}/${v}/node_modules/${n} ${path}/${peerResolutionString}/node_modules/${n}
          '')) peerResolution)}
        fi
      '');

      selfButt = let
        target = "${prevPath}/${optionalString (prevPeerResolutionString != null) "${prevPeerResolutionString}/"}node_modules/${name}";
      in optionalString (havePeers && prevPath != null) (indent ''
        rm -f ${target}
        ln -s ${path}/${peerResolutionString}/node_modules/${name} ${target}
      '');

      appendSeen = { name, version, seen ? [] }: seen ++ [ "${name}@${version}" ];
      filterSeen = seen: filterAttrs (name: version: ! builtins.elem "${name}@${version}" seen);
      filterEmpty = filter (str: str != "");

      depStrs = mapAttrsToList (name: version: mkPeerScriptFor {
        inherit name version;
        upperDeps = upperDeps // deps;
        depth = depth + 1;

        # This is used to break out of circular dependency situations
        seen = appendSeen {
          inherit (self) name version;
          inherit seen;
        };

        prevPath = path;
        prevPeerResolutionString = if ownPeerCount > 0 then peerResolutionString else null;
      }) (filterSeen seen deps);
    in concatStringsSep "\n" (filterEmpty ([ selfHead ] ++ depStrs ++ [ selfButt ]));

  in script;

  dependencies' = dependenciesFor context name version;

  copyBundled = let
    src = if self ? src then self.src else "${self.extracted}/lib/node_modules/${name}";
    hasBundled = (builtins.readDir src) ? node_modules;
  in optionalString hasBundled ''
    cp -r ${src + "/node_modules"}/* $outPath/node_modules
  '';

in runCommand "node-${drvName}-${drvVersion}-modules" {} (''
  set -eo pipefail
  export outPath="$out/lib"
  mkdir -p $outPath
'' + copyAllDeps + copyBundled + linkAllDeps + linkOwnDeps + linkAllBins + linkOwnBins + handlePeers + ''
  fixupPhase
'')
