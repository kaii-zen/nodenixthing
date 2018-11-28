{ newScope }:

let
  callPackage = newScope self;

  self = rec {
    mkBashCli           = callPackage ./make-bash-cli.nix { };
    mkNpmPackageContext = callPackage ./make-context      { };
    npmFetch            = callPackage ./npm-fetch.nix     { };
    nodenixthing        = callPackage ./nodenixthing      { };
  };
in self
