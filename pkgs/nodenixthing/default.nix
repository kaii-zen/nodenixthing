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

        eval set -- "$(getopt -o sof:: --long store,stdout,file -- "$@")"

        fileName=context.json
        store=false
        stdout=false

        while true ; do
          case "$1" in
            -f|--file)   fileName=$2 ; shift 2 ;;
            -s|--store)  store=true  ; shift   ;;
            -o|--stdout) stdout=true ; shift   ;;
            --) shift ; break ;;
            *) echo "Unrecognized option $1" ; exit 1 ;;
          esac
        done

        if $store; then
          fileName=$(mktemp)
        fi

        if ! $stdout; then
          ${/* Save original stdout fd so that we can restore it later */ ""}
	  exec 3>&1 1>$fileName
        fi

        nix-instantiate ${./make-context.nix} --argstr nixpkgs ${pkgs.path} --argstr nodenixthingRoot ${lib.cleanSource ../..} --strict --eval --json | jq .

        if $store; then
          ${/* Restore original stdout so that we can see the store path */ ""}
	  exec 1>&3 3>&-
          nix add-to-store --name context.json $fileName
          rm $fileName
        fi
      '')

      (c "fetch" "Fetch an npm package into the Nix store" ''
        PATH=${jq}/bin:${nix}/bin:$PATH


        if [[ $1 == --all ]]; then
          $0 make-context --stdout | jq -r '.[][] | "\(.name) \(.version) \(.resolved) \(.integrity)"' | grep -v 'null$' | xargs --max-args=4 --max-procs=8 $0 fetch
          exit $?
        fi

        name=''${1?Must specify derivation name}
        version=''${2?Must specify version}
        url=''${3?Must specify source URL}
        hash=''${4?Must specify hash}

        nix-build ${./fetch.nix} --no-out-link \
          --argstr nixpkgs ${pkgs.path} \
          --argstr nodenixthingRoot ${lib.cleanSource ../..} \
          --argstr name      "$name"    \
          --argstr version   "$version" \
          --argstr resolved  "$url"     \
          --argstr integrity "$hash"
      '')

      (c "fetch-context" "Fetch the tarballs for all npm packages required by the build context" ''
        PATH=${jq}/bin:${nix}/bin:$PATH

        if [[ -e context.json ]]; then
          ${/* This has to be an absolute path or nix complains */ ""}
          contextJSON=$PWD/context.json
        else
          contextJSON=$($0 make-context --store)
        fi

        if [[ -t 1 ]]; then
          nixBuild=(nix build --no-link -f)
        else
          nixBuild=(nix-build --no-out-link)
        fi

        exec "''${nixBuild[@]}" ${./fetch-context.nix} \
          --argstr nixpkgs ${pkgs.path} \
          --argstr nodenixthingRoot ${lib.cleanSource ../..} \
          --argstr contextJSON "$contextJSON"
      '')
    ]
  )
