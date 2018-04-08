import ../../default.nix {
  src = ./.;
  supplemental = with builtins; fromJSON (readFile ./supplemental.json);
}
