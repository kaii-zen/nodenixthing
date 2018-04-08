{ stdenv, parallel }:

with builtins;
rec {
  cp = if stdenv.isDarwin then "/bin/cp -c" else "cp --reflink=auto --sparse=always";
  copyDirectory = src: dst: ''
    mkdir -p ${dst}
    ${cp} -r ${src}/ ${dst}
    chmod -R u+w -- ${dst}
  '';

  runInParallel = mkParallelScript;
  mkParallelScript = scriptlets:
  assert isList scriptlets;
  let
    separator = "###";
  in ''
    cat << 'EOF' | ${parallel}/bin/parallel -j $(nproc) -N1 --pipe --recend '${separator}' bash
    ${concatStringsSep "\n${separator}\n" scriptlets}
    EOF
  '';

}
