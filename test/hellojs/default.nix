import ../../default.nix {
  srcPath = ./.;
  npmPkgOpts = {
    "hello:meow" = "woof";
  };
}
