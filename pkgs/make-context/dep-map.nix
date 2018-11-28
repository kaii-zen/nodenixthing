{ callPackage, lib }:

with lib;
with builtins;
with (callPackage ../../lib {});
let
  mkDepMap =
  { package
  , lock
  , supplemental ? {}
  }:
  assert isAttrs supplemental;
  let
    input = makeExtensible (_: {
      inherit package lock supplemental;
    });
    transforms = callPackage ./transformations.nix {};
    inputTransformed = input.extend transforms;
    depMap = inputTransformed.dependencies;
  in depMap;

  filterPackages = pred: depMap: filterAttrs (_: attrs: attrs != {}) (mapAttrs (name: versions: filterAttrs (pred name) versions) depMap);
  mapPackages = f: mapAttrs (name: mapAttrs (version: attrs: f name version attrs));

  extendPackages = context: extensions: mapPackages (name: version: attrs: let
    composedExtension = foldr composeExtensions (_: _: {}) extensions;
    pkg = applyExtension composedExtension attrs;
  in pkg) context;

  dependenciesFor = depMap: name: version:
  let
    dependenciesFor' = { requires ? {}, ... }: acc:
    let
      requires' = mapAttrs (name: version: { "${version}" = {}; }) requires;
      unseenRequires = filterPackages (name: version: _: ! (hasAttrByPath [ name version ] acc)) requires';
      expandedRequires = foldr dependenciesFor' (recursiveUpdate acc unseenRequires) (mapPackagesToList (name: version: _: depMap.${name}.${version}) unseenRequires);
    in if requires == {} then acc else expandedRequires;
  in mapPackages (name: version: _: depMap.${name}.${version}) (dependenciesFor' depMap.${name}.${version} {});

  getDependencies = src: depMap: name: version: let
    addPath = name: version: { self ? false }: depMap.${name}.${version} // {
      path = let
        getNpmPackage = callPackage ../npm/get.nix {} src;
        buildNixPackage = callPackage ../build-nix-package.nix {};
        npmPackage = getNpmPackage { inherit name version depMap; };
        nixPackage = buildNixPackage { inherit depMap npmPackage; };
      in if self then "" else nixPackage;
    };
  in mapPackages addPath (dependenciesFor depMap name version);

  mapPackagesToList = f: depMap: flatten (attrValues (mapAttrs (name: versions: attrValues (mapAttrs (version: attrs: (f name version attrs)) versions)) depMap));

  countPackages = depMap: length (mapPackagesToList (_: _: _: null) depMap);

  filterPackagesWithoutAttr = attr: let
    hasThatAttr = hasAttr attr;
    hasntThatAttr = notx hasThatAttr;
    thatAintGotThatAttr = discardxy hasntThatAttr;
  in filterPackages thatAintGotThatAttr;

  filterPackagesWithAttr = attr: let
    hasThatAttr = hasAttrs [attr];
    thatHasThatAttr = discardxy hasThatAttr;
  in filterPackages thatHasThatAttr;

  removeAllButSelf = filterPackagesWithAttr "self";
  removeSelf = filterPackagesWithoutAttr "self";
  removeDev = filterPackages (_: _: { dev ? false, ... }: !dev);
  removeNonDev = filterPackagesWithAttr "dev";
  # needIntegrity = filterPackages (_: _: attrs: !(attrs ? self) && attrs.integrity == "sha1-0000000000000000000000000000000000000000" && trace attrs true);
  needIntegrity = dm: let
    filtered = filterAttrs (_: versions: {} != versions) (mapAttrs (name: versions: (filterAttrs (version: attrs: !(attrs ? self) && attrs.integrity == "sha1-0000000000000000000000000000000000000000") versions)) dm);
    plucked = mapAttrs (_: versions: mapAttrs (_: attrs: filterAttrs (n: _: n == "integrity") attrs) versions) filtered;
  in plucked;
in {
  inherit countPackages mkDepMap removeSelf removeDev removeNonDev removeAllButSelf needIntegrity filterPackages mapPackagesToList mapPackages dependenciesFor getDependencies extendPackages;
}
