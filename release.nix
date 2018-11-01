{ nixpkgs ? <nixpkgs>
, systems ? [ builtins.currentSystem ] }:

let
  pkgs = import nixpkgs {};

in rec {
  tests = pkgs.lib.genAttrs systems (system: {
    hellojs        = import test/hellojs        { pkgs = import nixpkgs { inherit system; }; };
    hellojs-nogulp = import test/hellojs-nogulp { pkgs = import nixpkgs { inherit system; }; };
    helloweb       = import test/helloweb       { pkgs = import nixpkgs { inherit system; }; };
  });
}
