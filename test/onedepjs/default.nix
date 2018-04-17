let
  home = builtins.getEnv "HOME";
  idRsa = builtins.readFile "${home}/.ssh/id_rsa";
  npmRc = builtins.readFile "${home}/.npmRc";

in import ../../default.nix {
  src = ./.;
  supplemental = with builtins; fromJSON (readFile ./supplemental.json);
  inherit idRsa npmRc;
}
