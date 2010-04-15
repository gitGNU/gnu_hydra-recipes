{ nixpkgs ? { outPath = ../../nixpkgs; }
, gnulib ? { outPath = ../../gnulib; }
, patchSrc ? { outPath = ../../patch; } }:

let
  pkgs = import nixpkgs {};

  meta = {
    description = "GNU Patch, a program to apply differences to files";

    longDescription =
      '' GNU Patch takes a patch file containing a difference listing
         produced by the diff program and applies those differences to one or
         more original files, producing patched versions.
      '';

    homepage = http://savannah.gnu.org/projects/patch;

    license = "GPLv3+";

    maintainers =
     [ "Andreas Gruenbacher <agruen@gnu.org>"
       pkgs.stdenv.lib.maintainers.ludo
     ];
  };

  jobs = {
    tarball =
      with pkgs;
      releaseTools.sourceTarball {
        name = "patch";
        src = patchSrc;
        buildInputs = [ xz gettext texinfo automake111x ];
        autoconfPhase =
          '' cp -Rv "${gnulib}/"* gnulib/
             chmod -R 755 gnulib

             ./bootstrap --gnulib-srcdir=gnulib --skip-po --copy
          '';
        inherit meta;
      };

    build =
      { system ? builtins.currentSystem
      , tarball ? jobs.tarball }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "patch";
          src = tarball;
          failureHook =
            '' if [ -f tests/test-suite.log ]
               then
                   echo
                   echo "build failed, dumping test log..."
                   cat tests/test-suite.log
               fi
            '';
          inherit meta;
        };

    coverage =
      { tarball ? jobs.tarball }:

      let pkgs = import nixpkgs {};
      in
        pkgs.releaseTools.coverageAnalysis {
          name = "patch-coverage";
          src = tarball;
        };
  };
in
  jobs