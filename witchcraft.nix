{ pkgs, writeText, lib, callPackage, stdenv, runCommand, python, nodejs-8_x }:
{ contextJson, fallback }:

with lib;
with builtins;
with (callPackage ./util.nix {});
with (callPackage ./scriptlets.nix {});
with (callPackage ./context/dep-map.nix {});
let
  context = importJSON contextJson;

  extract = callPackage ./extract.nix {};

  importPackageJson = self: super: let
    src = if super ? extracted then "${self.extracted}/lib/node_modules/${self.name}" else fallback;
    packageJson = importJSON "${src}/package.json";
    hasBindingGyp = hasAttr "binding.gyp" (builtins.readDir src);
    hasInstallScript = hasAttrByPath [ "scripts" "install" ] packageJson;
    hasPrepareScript = hasAttrByPath [ "scripts" "prepare" ] packageJson;
    fromSource = super ? src;
    normalizeBin = {bin ? {},...}: if isString bin then { ${self.baseName} = bin; } else bin;
  in {
    inherit packageJson;
    shouldCompile = hasInstallScript || hasBindingGyp;
    shouldPrepare = fromSource && hasPrepareScript;
    bin = normalizeBin packageJson;
  };

  augmentedContext = extendPackages context [ extract importPackageJson ];

in writeText "context.json" (toJSON augmentedContext)
