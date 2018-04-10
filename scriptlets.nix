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
    cat << 'EOF' | ${parallel}/bin/parallel -j $(nproc) -N1 --pipe --recend '${separator}' bash
    ${concatStringsSep "\n${separator}\n" scriptlets}
    EOF
  '';

}
