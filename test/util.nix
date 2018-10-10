{ pkgs ? import nixpkgs { inherit system; }
, nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem }:

with builtins;
with pkgs.lib;
with (import ../util.nix { inherit pkgs; });
rec {
  callPackage = pkgs.callPackage;
  json = toJSON tests;
  tests = runTests {
    testResolveRequires = let
      resolveRequires = callPackage ../context/resolve-requires.nix {};
    in {
      expr = resolveRequires {
        requires = {
          moduleA = "some version constraint that we should ignore";
        };
        dependencies = {
          moduleA.version = "1.2.4";

          moduleB = {
            version = "4.3.2";
            requires.moduleA = "another version constraint we should ignore";
          };
        };
      };

      expected = {
        requires = {
          moduleA = "1.2.4";
        };

        dependencies = {
          moduleA.version = "1.2.4";
          moduleB = {
            version = "4.3.2";
            requires.moduleA = "1.2.4";
          };
        };
      };
    };

    testCopyNodeModules = let
      depMap = {
        packageA."1.0.0" = {
          requires = {
            packageB = "2.0.0";
            packageC = "2.0.0";
          };
        };

        packageB."2.0.0" = {
          path = "/packageB-2.0.0";
          requires = {
            packageD = "3.0.0";
          };
        };

        packageB."3.0.0" = {
          path = "/packageB-3.0.0";
          requires = {};
        };

        packageC."2.0.0" = {
          path = "/packageC-2.0.0";
          requires = {
            packageB = "3.0.0";
          };
        };

        packageD."3.0.0" = {
          path = "/packageD-3.0.0";
          requires = {
            packageB = "2.0.0";
          };
        };
      };

      copy = name: version: dest: "mkdir -p ${dest}/${name} ; cp -a ${depMap.${name}.${version}.path}/lib/node_modules/${name} ${dest}/${name}";

      cpNodeModulesFor = {name, version, dest ? "node_modules", copied ? {}}: let
        alreadyCopied = name: version: hasAttrByPath [ name version ] copied;
        depData = depMap.${name}.${version};
        dependencies = optionalAttrs (depData ? requires) depData.requires;
        copyPackage = name: version: optionals (! alreadyCopied name version) ([(copy name version dest)]
          ++ cpNodeModulesFor {
            inherit name version;
            copied = (recursiveUpdate copied (setAttrByPath [ name version ] null));
            dest = dest + "/${name}/node_modules";
          });
        copyPackages = mapAttrsToList copyPackage dependencies;
      in unique (flatten copyPackages);
    in {
      expr = cpNodeModulesFor { name = "packageA"; version = "1.0.0"; };
      expected = [
        (copy "packageB" "2.0.0" "node_modules")
        (copy "packageD" "3.0.0" "node_modules/packageB/node_modules")
        (copy "packageC" "2.0.0" "node_modules")
        (copy "packageB" "3.0.0" "node_modules/packageC/node_modules")
      ];
    };

    testFilterPackages = let
      inherit (callPackage ../context/dep-map.nix {}) filterPackages;
      input = {
        packageA."1.0.0" = { removeMe = true; };
        packageB."2.0.0" = { removeMe = false; };
        packageC."3.0.0" = { removeMe = false; };
        packageC."4.0.0" = { removeMe = true; };
      };

      output = {
        packageB."2.0.0" = { removeMe = false; };
        packageC."3.0.0" = { removeMe = false; };
      };
    in {
      expr = filterPackages (name: version: attrs: !(attrs ? removeMe && attrs.removeMe) ) input;
      expected = output;
    };
    testNormalizeNames = {
      expr = replaceStrings [ "@" "/" ] [ "" "-" ] "@organization/module-1.2.3";
      expected = "organization-module-1.2.3";
    };

    testTailIfHead = {
      expr = [
        (tailIfHead (equals 1) [1 2 3])
        (tailIfHead (not equal 2) [1 2 3])
        (tailIfHead (equals 2) [1 2 3])
      ];

      expected = [
        [2 3]
        [2 3]
        false
      ];
    };

    testDiscard =
    let
      discard0 = discard 0;
      discard1 = discard 1;
      discard2 = discard 2;
      anything = null;
    in {
      expr = [
        discard0
        (discard1 anything)
        (discard2 anything anything)
        # ((discard // { n = 2; }) 1 2)
        # ((discard // { n = 2; andReturn = true; }) 1 2)
        # ((discard // { n = 2; andReturn = id; }) 1 2 3)
      ];
      expected = [
        false
        false
        false
        # false
        # true
        # 3
        # 4
        # false
      ];
    };

    testMkStack = {
      expr = [
        mkStack.empty
        (mkStack 1).empty
        (mkStack 1 2).empty
        mkStack.top
        (mkStack 1).top
        (mkStack 1 2).top
        (mkStack 1 2).pop.top
        (mkStack 1 2 3).toList
      ];
      expected = [
        true
        false
        false
        null
        1
        2
        1
        [3 2 1]
      ];
    };

    testCompareArgsToList = {
      expr = [
        (compareArgsToList [1] 1)
        (compareArgsToList [1] 2)
        (compareArgsToList [1 2] 1 2)
        (compareArgsToList [1 2] 2 2)
      ];

      expected = [
        true
        false
        true
        false
      ];
    };

    testRemoveAttrRecursive = {
      expr = removeAttrRecursive "removeMe" {
        a = {
          b = 1;
          removeMe = [2 3 4];
        };
        removeMe = [5 6 7];
      };
      expected = {
        a = {
          b = 1;
        };
      };
    };

    testHoistAttr = {
      expr = hoistAttr "name" {
        name = "awesome";
        version = "1.0.0";
        description = "blah blah blah";
      };

      expected = {
        awesome = {
          name = "awesome";
          version = "1.0.0";
          description = "blah blah blah";
        };
      };
    };

    testHoistAttrs = {
      expr = hoistAttrs "version" {
        package = {
          version = "1.0.0";
          description = "blah blah blah";
        };
      };
      expected = {
        package = {
          "1.0.0" = {
            description = "blah blah blah";
            version = "1.0.0";
          };
        };
      };
    };

    testIsAttrAndHasAttr = {
      expr = {
        inputIsAttrsAndAttrExistsShouldReturnTrue = isAttrsAndHasAttr "a" { a = "whatever"; };
        inputIsAttrsButAttrDoesntExistShouldReturnFalse = isAttrsAndHasAttr "a" { b = "whatever"; };
        inputIsStringShouldReturnFalse = isAttrsAndHasAttr "a" "lol I'm not even a set 🤪";
      };

      expected = {
        inputIsAttrsAndAttrExistsShouldReturnTrue = true;
        inputIsAttrsButAttrDoesntExistShouldReturnFalse = false;
        inputIsStringShouldReturnFalse = false;
      };
    };

    testAllTheThings =
    let
      package = {
        name = "hello";
        version = "1.0.0";
        dependencies = {
          depA = "^2.3.1";
          depB = "~1.4.0";
          depWithBundled = "~3.2.0";
        };
        devDependencies = {
          devDepA = "^2.1.1";
        };
      };
      lock = {
        name = "mypkg";
        version = "1.0.0";
        requires = true;
        dependencies = {
          depA = {
            version = "2.5.2";
            resolved = "https://registry.npmjs.org/depA/-/depA-2.5.2.tgz";
            integrity = "sha512-QUU4ofkDoMIVO7hcx1iPTISs88wsO8jA92RQIm4JAwZvFGGAV2hSAA1NX7oVj2Ej2Q6NDTcRDjPTFrMCRZoJ6g==";
            requires = {
              depB = "2.0.1";
            };
            dependencies = {
              depB = {
                version = "2.0.1";
                resolved = "https://registry.npmjs.org/depB/-/depB-2.0.1.tgz";
                integrity = "sha1-n37ih/gv0ybU/RYpI9YhKe7g368=";
              };
            };
          };

          depB = {
            version = "1.4.7";
            resolved = "https://registry.npmjs.org/depB/-/depB-1.4.7.tgz";
            integrity = "sha1-s12sN2R5+sw+lHR9QdDQ9SOP/LU=";
          };

          # Example of a dependency with bundled dependencies.
          depWithBundled = {
            version = "3.2.1";
            resolved = "https://registry.npmjs.org/depWithBundled/-/depWithBundled-3.2.1.tgz";
            integrity = "sha512-F39vS48la4YvTZUPVeTqsjsFNrvcMwrV3RLZINsmHo+7djCvuUzSIeXOnZ5hmjef4bajL1dNccN+tg5XAliO5Q==";
            requires = {
              bundledDep = "1.4.2";
              nonBundledDep = "1.6.2";
            };

            dependencies = {
              bundledDep = {
                version = "1.4.2";
                bundled = true;
                requires = {
                  depOfBundledDep = "2.4.1";
                };
              };

              nonBundledDep = {
                version = "1.6.2";
                resolved = "https://registry.npmjs.org/nonBundledDep/-/nonBundledDep-1.6.2.tgz";
                integrity = "sha512-QUU4ofkDoMIVO7hcx1iPTISs88wsO8jA92RQIm4JAwZvFGGAV2hSAA1NX7oVj2Ej2Q6NDTcRDjPTFrMCRZoJ6g";
              };

              # A dependency of a bundled dependency is implicitly bundled as well.
              depOfBundledDep = {
                version = "2.4.1";
                bundled = true;
              };
            };
          };

          devDepA = {
            version = "2.2.3";
            resolved = "https://registry.npmjs.org/devDepA/-/devDepA-2.2.3.tgz";
            integrity = "sha1-G2HAViGQqN/2rjuyzwIAyhMLhtQ=";
            dev = true;
          };
        };
      };

      input = makeExtensible (_: { inherit package lock; supplemental = {}; });
      output = input.extend (callPackage ../context/transformations.nix {});
    in
    {
      expr = with output; let
        inputNormalized = with normalizedInput; let
          nameHoisted = mypkg.version == "1.0.0";
          requiresDerived = mypkg.requires.depA == "2.5.2";
        in nameHoisted && requiresDerived;
        bundledDependenciesRemoved = ! dependencies.depWithBundled."3.2.1".requires ? bundledDep && ! dependencies ? bundledDep;
        dependenciesFlattened = dependencies.mypkg."1.0.0".requires.depA == "2.5.2" && dependencies.depA."2.5.2".requires.depB == "2.0.1";
      in all id [inputNormalized bundledDependenciesRemoved dependenciesFlattened];
      expected = true;
    };

    testRemoveBundledDependencies =
    let
      filterRequires = requires: dependencies: filterAttrs (name: _: ! hasAttrByPath [name "bundled"] dependencies) requires;
      filterDependencies = dependencies: filterAttrs (_: v: ! v ? bundled) dependencies;
      filterBundled = deps: filterAttrsRecursive (_: v: v != {}) (mapAttrs (_: dep: dep // optionalAttrs (dep ? dependencies) {
        requires = optionalAttrs (dep ? requires) (filterRequires dep.requires dep.dependencies);
        dependencies = filterDependencies (filterBundled dep.dependencies);
      }) deps);
    in {
      expr = filterBundled {
        depWithBundled = {
          version = "3.2.1";
          requires = {
            bundledDep = "1.4.2";
            nonBundledDep = "1.6.2";
            nonBundledDepWithBundledDeps = "1.7.3";
          };

          dependencies = {
            bundledDep = {
              version = "1.4.2";
              bundled = true;
              requires = {
                depOfBundledDep = "2.4.1";
              };
            };

            nonBundledDepWithBundledDeps = {
              version = "1.7.3";

              requires = {
                nestedBundledDep = "3.7.1";
              };

              dependencies = {
                nestedBundledDep = {
                  version = "3.7.1";
                  bundled = true;
                };
              };
            };

            nonBundledDep = {
              version = "1.6.2";
            };

            # A dependency of a bundled dependency is implicitly bundled as well.
            depOfBundledDep = {
              version = "2.4.1";
              bundled = true;
            };
          };
        };
      };
      expected = {
        depWithBundled = {
          version = "3.2.1";
          requires = {
            nonBundledDep = "1.6.2";
            nonBundledDepWithBundledDeps = "1.7.3";
          };

          dependencies = {
            nonBundledDep = {
              version = "1.6.2";
            };
            nonBundledDepWithBundledDeps = {
              version = "1.7.3";
            };
          };
        };
      };
    };
  };
}
