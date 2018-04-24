{ stdenv, parallel }:

with builtins;
rec {
  copyDirectory = src: dst:
  if stdenv.isDarwin then ''
    mkdir -p ${dst}
    /bin/cp -c -r ${src}/ ${dst}
    chmod -R u+w -- ${dst}
  '' else ''
    cp --reflink=auto --sparse=always -r ${src} ${dst}
    chmod -R u+w -- ${dst}
  '';

  runInParallel = mkParallelScript;
  mkParallelScript = scriptlets:
  assert isList scriptlets;
  let
    separator = "###";
  in ''
    set -eo pipefail
    cat << 'EOF' | ${parallel}/bin/parallel -j $(nproc) -N1 --halt now,fail=1 --pipe --recend '${separator}' bash
    set -eo pipefail
    ${concatStringsSep "\n${separator}\n" scriptlets}
    EOF
  '';

}
