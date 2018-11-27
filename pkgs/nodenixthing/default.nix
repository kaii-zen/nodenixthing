{ mkBashCli, writeText }:

mkBashCli "nnt" "CLI for working with Nix in NPM projects" {
  doCheck = true;
  checkPhase = ''
    $binary init
    grep "^use nix$" .envrc
    test -w .envrc
    test -w shell.nix
  '';
} (c:
    [
      (c "init" "Initialize a new project" ''
        install -m 644 ${writeText "envrc" "use nix"} .envrc
        install -m 644 ${./shell.nix} shell.nix
      '')
    ]
  )
