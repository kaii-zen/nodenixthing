{ newScope }:

let
  callPackage = newScope self;

  self = rec {
    mkBashCli = callPackage ./make-bash-cli.nix {};
    nodenixthing = callPackage ./nodenixthing {};
  };
in self
