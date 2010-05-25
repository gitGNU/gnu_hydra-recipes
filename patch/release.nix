{ nixpkgs ? { outPath = ../../nixpkgs; }
, gnulib ? { outPath = ../../gnulib; }
, patchSrc ? { outPath = ../../patch; } }:

let
  pkgs = import nixpkgs {};
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

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
        buildInputs =
          [ git xz gettext texinfo
            bison # the `testing' branch needs it
          ];
        autoconfPhase =
          '' git config submodule.gnulib.url "${gnulib}"
             ./bootstrap --gnulib-srcdir="${gnulib}" --skip-po
          '';

        automake = pkgs.automake111x;
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

    xbuild_gnu =
      # Cross build to GNU.
      { tarball ? jobs.tarball }:

      let pkgs = import nixpkgs {
            crossSystem = crossSystems.i586_pc_gnu;
          };
      in
      (pkgs.releaseTools.nixBuild {
	name = "patch" ;
	src = tarball;
        doCheck = false;
        inherit meta;
      }).hostDrv;

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
