{ lib, curl, perl, writeText, stdenvNoCC, nodejs-8_x, git, openssh
, idRsa ? ""
, npmRc ? ""
}:

{ resolved
, integrity
, name
, version , # Meta information, if any.
  meta ? {}
  # Passthru information, if any.
, passthru ? {}
, ...
}:

with lib;
let
  integritySplit = (splitString "-" integrity);
  outputHashAlgo = head integritySplit;
  outputHash = last integritySplit;

  url = resolved;
  isGit = if builtins.match "^.*#.*$" url == null then false else true;

in stdenvNoCC.mkDerivation {
  inherit url version;
  pname  = name;
  name = "node-${builtins.replaceStrings [ "#" ] [ "-" ] (baseNameOf (toString url))}";

  inherit npmRc idRsa;

  setupSsh = ''
    mkdir -p .ssh
    cp $idRsaPath .ssh/id_rsa
    chmod 700 .ssh
    chmod 600 .ssh/id_rsa
    export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -F /dev/null"
  '';

  passAsFile = [ "idRsa" "npmRc" "setupSsh" ];

  buildCommand = ''
    export HOME=$TMPDIR
    set -eo pipefail

    function rm_secrets {
      rm -f ~/.npmrc ~/.ssh/id_rsa ~/env-vars
    }

    trap rm_secrets EXIT

    cp $npmRcPath .npmrc

    source $setupSshPath

    tgzFile=$(npm pack $url | tail -n1)
  '' + optionalString isGit ''
    tar xzf $tgzFile
    tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner -c package | gzip -n > $tgzFile
  '' + ''
    cp $tgzFile $out
  '';

  nativeBuildInputs = [ nodejs-8_x git openssh curl ];

  # New-style output content requirements.
  inherit outputHashAlgo outputHash;
  outputHashMode = "flat";

  # Doing the download on a remote machine just duplicates network
  # traffic, so don't do that.
  preferLocalBuild = true;

  inherit meta;
  inherit passthru;
}
