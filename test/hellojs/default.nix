import ../../default.nix {
  src = ./.;
  npmPkgOpts = {
    "hello:meow" = "woof";
  };
}
