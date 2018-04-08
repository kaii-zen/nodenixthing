{ lib, writeText, callPackage, runCommand, nodejs-8_x }:
{ name, version, context }:

with lib;
with (callPackage ./scriptlets.nix {});
with (callPackage ./context/dep-map.nix {});
with (callPackage ./util.nix {});
let
  dependencies = dependenciesFor context name version;

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
    ${copyDirectory attrs.built "$moduleDir"}
  '';

  mkUntarPackageScriptlet = name: version: attrs: ''
    export moduleDir="$outPath/${allModulesDir}/${name}/${version}/node_modules/${name}"
    mkdir -p $moduleDir
    tar xf ${attrs.npmPackage} --warning=no-unknown-keyword --directory=$moduleDir --strip-components=1
  '';

  linkDependency = name: version: ''
    target=$outPath/${allModulesDir}/${name}/${version}/node_modules/${name}
    mkdir -p ${name}
    rmdir ${name}
    ln -s $target ${name}
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

  mkScript = { scriptletGenerator }: mkParallelScript (mapPackagesToList scriptletGenerator dependencies);

  copyScript    = mkScript { scriptletGenerator = mkCopyPackageScriptlet; };
  untarAllDeps  = mkScript { scriptletGenerator = mkUntarPackageScriptlet; };
  linkAllDeps   = mkScript { scriptletGenerator = mkLinkPackageScriptlet; };
  linkAllBins   = mkScript { scriptletGenerator = mkLinkAllBinsScriptlet; };
  handlePeers   = mkScript { scriptletGenerator = mkHandlePeersScriptlet; };

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

  mkHandlePeersScriptlet = name: version: {packageJson,...}: let
    # path = extracted;
    # path = "${extracted}/${allModulesDir}/${name}/${version}/node_modules/${name}";
    # packageJson = importJSON "${path}/package.json";
    dependencyPath = "$outPath/${allModulesDir}/${name}/${version}";
    printDependency = { peerDependencies ? {}, ... }: let
      peerNames = attrNames peerDependencies;
      peerCount = length (peerNames);
      hasPeers = peerCount > 0;
      announcePeers = optionalString hasPeers printPeerInfo;
      requirers = filterPackages (_: _: { requires ? {}, ...}: requires ? ${name} && requires.${name} == version) dependencies;
      requirersList = mapPackagesToList (requirerName: requirerVersion: { self ? false, requires, ... }: let
        peerResolution = genAttrs peerNames (n: requires.${n});
        resolutionString = concatStringsSep "+" (mapAttrsToList (n: v: "${n}@${v}") peerResolution);
        resolutionPath = "${dependencyPath}/${resolutionString}";
        requirerNodeModulesPath = "$outPath/${allModulesDir}/${requirerName}/${requirerVersion}/node_modules";
      in optionalString (hasAttrs peerNames requires) ''
        cd ${requirerNodeModulesPath}
        if ! [[ -d ${resolutionPath} ]]; then
          mkdir -p ${resolutionPath}
          cp -a ${dependencyPath}/node_modules ${resolutionPath}/node_modules
          ${concatStrings (mapAttrsToList (n: v: ''
            rm -f ${resolutionPath}/node_modules/${n}
            ln -s $outPath/${allModulesDir}/${n}/${v}/node_modules/${n} ${resolutionPath}/node_modules/${n}
          '') peerResolution)}
        fi
        rm -f ${name}
        ln -s ${resolutionPath}/node_modules/${name} ${name}
      '') requirers;
      requirersCount = length requirersList;
      printPeerInfo = concatStrings requirersList;
    in ''
      ${announcePeers}
    '';
  in ''
    cd ${dependencyPath}
    ${printDependency packageJson}
  '';

  copyBundled = let
    src = if self ? extracted then "${self.extracted}/lib/node_modules/${name}" else self.src;
  in ''
    if [[ -d ${src}/node_modules ]]; then
      cp -r ${src}/node_modules/* $outPath/node_modules
    fi
  '';

in runCommand "node-${drvName}-${drvVersion}-modules" {} (''
  export outPath="$out/lib"
  mkdir -p $outPath
'' + untarAllDeps + copyBundled + linkAllDeps + linkOwnDeps + linkAllBins + linkOwnBins + handlePeers)
