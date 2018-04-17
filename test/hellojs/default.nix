import ../../default.nix {
  #src = builtins.path {
  #  path = ./.;
  #  filter = path: type: type != "symlink" && ! builtins.elem (baseNameOf path) [ ".git" "node_modules" ];
  #};
  srcPath = ./.;

  npmPkgOpts = {
    "hello:meow" = "woof";
  };
}
