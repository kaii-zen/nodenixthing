let
  pkgs = import ./nixpkgs.nix {};
in

with pkgs;

mkShell {
  buildInputs = [ nodejs nodenixthing ];
}
 
