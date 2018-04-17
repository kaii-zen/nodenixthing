{ pkgs, callPackage, runCommand }:

# We are going to gradually and gently massage the data acquired from package.json and npm-shrinkwrap.json/package-lock.json
# until we (hopefully 😅) end up with a flat attrset of inter-dependent derivations.
with pkgs.lib;
with (callPackage ../util.nix {});
with (callPackage ./dep-map.nix {});
let
  normalizeInput = self: super: {
    normalizedInput.${self.lock.name} = self.lock // {
      #inherit (self) src;
      self = true;
      packageJson = self.package;
      requires = let
        mkRequires = { dependencies ? {}, devDependencies ? {}, optionalDependencies ? {}, ...}:
          genAttrs ((attrNames dependencies) ++ (attrNames devDependencies) ++ (attrNames optionalDependencies)) (depName: self.lock.dependencies."${depName}".version);
      in mkRequires self.package;
    };
  };

  flattenDependencies = let
    # 1) Filter out bundled dependencies. We don't care about those since they're already included in the npm package and we don't need to do anything about them.
    #    Moreover, if we leave them they cause infinite recursion.
    #    At this point we assume that the package author had a good reason to bundle their dependencies and we're going to leave it at that.
    removeBundledRequires = self: super: let
      filterRequires = requires: dependencies: filterAttrs (name: _: ! hasAttrByPath [name "bundled"] dependencies) requires;
      filterDependencies = dependencies: filterAttrs (_: v: ! v ? bundled) dependencies;
      filterBundled = deps: filterAttrsRecursive (_: v: v != {}) (mapAttrs (_: dep: dep // optionalAttrs (dep ? dependencies) {
        requires = optionalAttrs (dep ? requires) (filterRequires dep.requires dep.dependencies);
        dependencies = filterDependencies (filterBundled dep.dependencies);
      }) deps);
    in {
      dependencies = filterBundled self.normalizedInput;
    };
    # 2) Crawl down the tree and collect all nested dependency sets.
    #    Reminder: we only end up with a nested dependency set when a dependency has a dependency with a version constraint that conflicts with the root (or any upper-level) dependency set.
    #    Yes, it's a mouthful. Take a deep breath, maybe pack a bowl and revisit. It makes sense eventually I swear.
    #    Now since we might have multiple versions of the same module we need to keep things separate for now so that we don't overwrite things so we want to end up with an array of attrsets,
    #    each of which is a different set of nested dependencies.
    collectNestedDependencies = self: super: {
      dependencies = collectValuesByNameRecursive "dependencies" super.dependencies;
    };
    # 3) We want to "hoist" the version attributes up. Similar to what we did for the "root" package name, only this time we have to do it across the board. Luckily we don't have to do it recursively since
    #    we already got an array of all the nested dependencies.
    hoistVersions = self: super: {
      dependencies = map (hoistAttrs "version") super.dependencies;
    };
    # 4) Since we now have this extra level in our attrset to account for potential different versions of the same package, we can go ahead and merge all the attrsets in the array.
    merge = self: super: {
      dependencies = foldr (lhs: rhs: let
        normalizeDev = mapPackages (_: _: { dev ? false, ...}@a: a // { inherit dev; });
        alreadyHaveIt = name: version: hasAttrByPath [ name version ] lhs;
        shouldSkip = name: version: {dev, ...}: dev && (alreadyHaveIt name version);
        shouldntSkip = notxyz shouldSkip;
        filterDev = filterPackages shouldntSkip;
        rhs' = filterDev (normalizeDev rhs);
      in recursiveUpdate lhs rhs') {} super.dependencies;
    };
    # 5) Prune nested dependencies
    pruneNestedDependencies = self: super: {
      dependencies = removeAttrRecursive "dependencies" super.dependencies;
    };
    overlaySupplemental = self: super: {
      dependencies = recursiveUpdate super.dependencies self.supplemental;
    };
  in composeMultipleExtensions [removeBundledRequires collectNestedDependencies hoistVersions merge pruneNestedDependencies overlaySupplemental];

  misc = let
    resolveGit = _: super: {
      dependencies = extendPackages super.dependencies [
        (self: super: let
          inherit (super) version;
          isGit = builtins.match ".*#.*" version != null;
          integrityPlaceHolder = "sha1-0000000000000000000000000000000000000000";
        in optionalAttrs isGit {
          resolved = version;
          integrity = if (super ? integrity) then super.integrity else integrityPlaceHolder;
        })
      ];
    };
    addName = _: super: {
      dependencies = mapPackages (name: version: attrs: let
        matchScope = builtins.match "^(@.*)/(.*)$" name;
        hasScope = matchScope != null;
        scope = optionalString hasScope (head matchScope);
        baseName = if hasScope then (last matchScope) else name;
        drvName = replaceStrings [ "@" "/" ] [ "" "-" ] name;
        drvVersion = let
          matchGit = builtins.match "^git.*#(.*)$" version;
        in if matchGit == null then version else head matchGit;
      in attrs // {
        inherit name version drvName drvVersion scope baseName;
      }) super.dependencies;
    };
    collectMissingIntegrity = self: super: {
      missingIntegrity = needIntegrity self.dependencies;
    };
  in composeMultipleExtensions [addName resolveGit collectMissingIntegrity];

in composeMultipleExtensions [normalizeInput flattenDependencies misc]
