{ nodenixthingRoot
, contextJSON
, npmRc            ? ""
, nixpkgs          ? <nixpkgs>
, pkgs             ? import nixpkgs {}
, nodenixthingPkgs ? pkgs.callPackages "${nodenixthingRoot}/pkgs" {}}:

with pkgs.lib;

nodenixthingPkgs.fetchContext {
  inherit npmRc;
  context = importJSON contextJSON;
}
