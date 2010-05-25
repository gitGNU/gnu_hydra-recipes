{ nixpkgs ? { outPath = ../../nixpkgs; }
, gnulib ? { outPath = ../../gnulib; }
, findutilsSrc ? { outPath = ../../findutils; } }:

let
  pkgs = import nixpkgs {};

  meta = {
    description = "GNU Findutils, a program to find files";

    longDescription =
      '' The GNU Find Utilities are the basic directory searching utilities
         of the GNU operating system. These programs are typically used in
         conjunction with other programs to provide modular and powerful
         directory search and file locating capabilities to other commands.
      '';

    homepage = http://savannah.gnu.org/projects/findutils;

    license = "GPLv3+";

    maintainers =
     [ "James Youngman <jay@gnu.org>"
       pkgs.stdenv.lib.maintainers.ludo
     ];
  };

  jobs = {
    tarball =
      with pkgs;
      releaseTools.sourceTarball {
	name = "findutils-tarball";
	src = findutilsSrc;
	buildInputs =
          [ gettext gperf bison groff git
            texinfo xz
            cvs # for `autopoint'
          ];
	autoconfPhase =
          # `gnulib-tool' wants write access to the Gnulib directory, e.g.,
          # to create `./build-aux/arg-nonnull.h.tmp'.  Thus we have to copy
          # the whole Gnulib tree in a writable place.
	  '' cp -rv "${gnulib}" ../gnulib
             chmod -R u+w ../gnulib
             sh ./import-gnulib.sh -d ../gnulib
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
	  name = "findutils";
	  src = tarball;
          buildInputs = [ pkgs.dejagnu ];
	  inherit meta;
	};

    coverage =
      { tarball ? jobs.tarball }:

      let pkgs = import nixpkgs {};
      in
	pkgs.releaseTools.coverageAnalysis {
	  name = "findutils-coverage";
	  src = tarball;
          buildInputs = [ pkgs.dejagnu ];
	};
  };
in
  jobs
