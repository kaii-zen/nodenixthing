{ callPackage, lib, runCommand }:
src:
{ name, version, depMap, npmPackage ? null }:

with lib;
let
  fetchNpmPackage = callPackage ./fetch.nix {};
  data = depMap.${name}.${version};
  # Boolean - true if we are the main package being built, false if we're a dependency.
  self = data ? self;
  dependency = ! self;
  resolved = data ? resolved;
  npmPack = let
    derefLink = runCommand "${name}-${version}-symlink-deref" {} ''
      readlink -f ${src}/node_modules/${name} > $out
    '';
    realPath = builtins.path { path = fileContents derefLink; };
  in runCommand "${name}-${version}-packed-locally.tgz" {} ''
    tar czf $out --directory ${realPath} --transform s/^${name}/package/ .
  '';

in
  if self then npmPackage
  else if resolved then
    fetchNpmPackage (data // { inherit name version; })
  else
    npmPack

# npm.get { name, version, context } -> tarball
# npm.build { src, context } -> tarball
# npm.fetch { resolved, integrity}
