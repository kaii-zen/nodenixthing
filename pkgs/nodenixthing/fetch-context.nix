{ nodenixthingRoot
, contextJSON
, nixpkgs          ? <nixpkgs>
, pkgs             ? import nixpkgs {}
, nodenixthingPkgs ? pkgs.callPackages "${nodenixthingRoot}/pkgs" {}}:

with pkgs.lib;

nodenixthingPkgs.fetchContext {
  context = importJSON contextJSON;
}
