{ callPackage, writeText, lib }:
{ package, lock, supplemental ? {}}:

with builtins;
assert isAttrs package;
assert isAttrs lock;
assert isAttrs supplemental;

with lib;
let
  input = makeExtensible (_: {
    inherit package lock supplemental;
  });
  transforms = callPackage ./transformations.nix {};
  inputTransformed = input.extend transforms;
  context = inputTransformed.dependencies;

in writeText "context.json" (toJSON context)
