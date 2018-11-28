# npm@6 changed the format of package-lock.json/npm-shrinkwrap.json and it now has
# version constraints in the `requires` stanzas rather than resolved versions. That means
# we now have to work harder to find the absolute resolved versions from the the immediate
# `dependencies` stanza as well as upper in the graph.
{ lib }: with lib;

let
  resolveRequires' = acc: input: let
    versionMap = let
      current = optionalAttrs (input ? dependencies) (mapAttrs (_: value: value.version) input.dependencies);
      previous = acc;
    in previous // current;
    versionOf = moduleName: versionMap.${moduleName};
    moduleNames = attrNames input.requires;
    resolvedRequires = {
      requires = genAttrs moduleNames versionOf;
    };
    resolvedDependencies = {
      dependencies = mapAttrs (_: resolveRequires' versionMap) input.dependencies;
    };
  in input //
    (optionalAttrs (input ? requires) resolvedRequires) //
    (optionalAttrs (input ? dependencies) resolvedDependencies);
in resolveRequires' {}
