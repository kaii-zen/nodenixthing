context:

{
    fetch = import ./fetch.nix { inherit context; };
    build = import ./build.nix { inherit context; };
}