{ writeText, callPackage, nodejs, lib, runCommand }:
depMap:
{ name, version, src }:

with lib;
with (callPackage ../context/dep-map.nix {});
with (callPackage ../scriptlets.nix {});
with (callPackage ../util.nix {});
let
  dependenciesDir = "node_modules/.all";

  dependencies = getDependencies src depMap name version;
  forEachDependency = f: mapPackagesToList f dependencies;
  forSelf = f: f name version depMap.${name}.${version};
  forAll = f: (forEachDependency f) ++ [ (forSelf f) ];
  isSelf = name': version': _: name == name' && version == version';

  linkDependency = name: version: ''
    target=$dependenciesDir/${name}/${version}/node_modules/${name}
    mkdir -p ${name}
    rmdir ${name}
    ln -s $target ${name}
  '';

  linkRequires = name: version: attrs@{ requires ? {} , ...}:
  let
    self = isSelf name version attrs;
    nodeModulesPath = if self then "$projectNodeModules" else "$dependenciesDir/${name}/${version}/node_modules";
  in ''
    cd ${nodeModulesPath}
    ${concatStrings (mapAttrsToList linkDependency requires)}
  '';

  linkBins = name: version: attrs@{requires ? {}, ...}: let
    self = isSelf name version attrs;
    nodeModulesPath = if self then "$projectNodeModules" else "$dependenciesDir/${name}/${version}/node_modules";
    binPath = if self then "${nodeModulesPath}/.bin" else "${nodeModulesPath}/${name}/node_modules/.bin";
  in ''
    find -L ${nodeModulesPath}/ -mindepth 2 -maxdepth 2 -name package.json -exec ${nodejs}/bin/node ${../nix-bin.js} {} \; | \
      xargs --max-args=3 --no-run-if-empty bash -c '[[ $1 == ${name} ]] || (mkdir -p ${binPath} ; ln -s $(readlink -f ${nodeModulesPath}/$1/$3) ${binPath}/$2)' _
  '';

  copyDependencies = let
    copyDependency = name: version: {path,...}: let
      src = "${path}/lib/node_modules/${name}";
      dst = "${name}/${version}/node_modules/${name}";
    in copyDirectory src dst;
  in runInParallel (forEachDependency copyDependency);

  setupDependencies = let
    setupDependency = name: version: {path,...}: let
      packageJson = importJSON "${path}/lib/node_modules/${name}/package.json";
      dependencyPath = "$dependenciesDir/${name}/${version}";
      printDependency = { peerDependencies ? {}, ... }: let
        peerNames = attrNames peerDependencies;
        peerCount = length (peerNames);
        hasPeers = peerCount > 0;
        announcePeers = optionalString hasPeers printPeerInfo;
        requirers = filterPackages (_: _: { requires ? {}, ...}: requires ? ${name} && requires.${name} == version) depMap;
        requirersList = mapPackagesToList (requirerName: requirerVersion: { self ? false, requires, ... }: let
          peerResolution = genAttrs peerNames (n: requires.${n});
          resolutionString = concatStringsSep "+" (mapAttrsToList (n: v: "${n}@${v}") peerResolution);
          resolutionPath = "${dependencyPath}/${resolutionString}";
          requirerNodeModulesPath = if self then "$projectNodeModules" else "$dependenciesDir/${requirerName}/${requirerVersion}/node_modules";
        in optionalString (hasAttrs peerNames requires) ''
          cd ${requirerNodeModulesPath}
          if ! [[ -d ${resolutionPath} ]]; then
            mkdir -p ${resolutionPath}
            cp -a ${dependencyPath}/node_modules ${resolutionPath}/node_modules
            ${concatStrings (mapAttrsToList (n: v: ''
              rm -f ${resolutionPath}/node_modules/${n}
              ln -s $dependenciesDir/${n}/${v}/node_modules/${n} ${resolutionPath}/node_modules/${n}
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
      cd $dependenciesDir/${name}/${version}
      ${printDependency packageJson}
    '';
  in runInParallel (forEachDependency setupDependency);

  linkAllDependencies     = runInParallel (forEachDependency linkRequires);
  linkProjectDependencies = forSelf linkRequires;
  linkAllBins             = runInParallel (forAll linkBins);

  script = ''
    mkdir -p $out
    cd $out
    if [[ -d ${src}/node_modules ]]; then
      ${copyDirectory "${src}/node_modules" "node_modules"}
    fi
    mkdir -p node_modules ${dependenciesDir}
    export dependenciesDir=$(realpath ${dependenciesDir})
    export projectNodeModules=$(realpath node_modules)

    cd $dependenciesDir

    ${copyDependencies}
    ${linkAllDependencies}
    ${linkProjectDependencies}
    ${linkAllBins}
    ${setupDependencies}
  '';

in runCommand "${name}-${version}-node_modules" {} script
