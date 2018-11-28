{ pkgs, mkBashCli, lib, writeText, nix-prefetch-git, nix, jq, rev ? null }:

mkBashCli "nnt" "CLI for working with Nix in NPM projects" {
  doCheck = true;

  checkPhase = ''
    set -eo pipefail

    export TEST_MODE=true 

    $binary init

    grep "^use nix$" .envrc
    test -w .envrc
    test -w shell.nix

    $binary nuke

    for f in *.json *.nix .envrc; do
      ! test -e $f
    done
  '';
} (c:
    [
      (c "init" "Initialize a new project" ''
        install -m 644 ${writeText "envrc" ''
          use nix
          watch_file nixpkgs.json
          watch_file nixpkgs.nix
          watch_file nodenixthing.json
        ''} .envrc

        install -m 644 ${./shell.nix} shell.nix
        install -m 644 ${./nixpkgs.nix} nixpkgs.nix

        if ! ''${TEST_MODE:-false}; then
          PATH=${nix-prefetch-git}/bin:$PATH
          nix-prefetch-git https://github.com/kreisys/nodenixthing > nodenixthing.json
          nix-prefetch-git https://github.com/NixOS/nixpkgs-channels > nixpkgs.json
        fi
      '')

      (c "nuke" "Remove all files created by init" ''
        rm -f .envrc shell.nix nixpkgs.nix nodenixthing.json nixpkgs.json
      '')

      (c "make-context" "Generate a context.json file from package.json and npm-shrinkwrap.json" ''
        PATH=${jq}/bin:${nix}/bin:$PATH
        if [[ $1 != --stdout ]]; then
          exec 1>context.json
        fi
        nix-instantiate ${./make-context.nix} --argstr nixpkgs ${pkgs.path} --argstr nodenixthingRoot ${lib.cleanSource ../..} --strict --eval --json | jq .
      '')


      '')
    ]
  )
