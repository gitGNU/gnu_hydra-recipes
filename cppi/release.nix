{ nixpkgs ? ../../nixpkgs 
, cppi ? { outPath = ../../cppi; }
, gnulib ? {outPath = ../../gnulib;}
}:

let
  meta = {
    homepage = http://savannah.gnu.org/projects/cppi/;

    description = "GNU cppi, a cpp directive indenter";

    longDescription =
      '' GNU cppi indents C preprocessor directives to reflect their nesting
         and ensure that there is exactly one space character between each #if,
         #elif, #define directive and the following token.  The number of
         spaces between the `#' and the following directive must correspond
         to the level of nesting of that directive.
      '';

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [ 
      "Jim Meyering <jim@meyering.net>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

  pkgs = import nixpkgs {};

  jobs = rec {

    tarball = with pkgs;
      releaseTools.makeSourceTarball {
	name = "cppi-tarball";
	src = cppi;
        inherit meta;

        autoconfPhase = ''
          mkdir -p ../gnulib
          cp -Rv ${gnulib}/* ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --skip-po --copy
        '';

	buildInputs = [
          automake111x
          texinfo
          gettext
          git 
          wget
          perl
          rsync
          flex2535
          help2man
          gperf
          cvs
	];
      };

    build =
      { system ? "x86_64-linux"
      }:
      let pkgs = import nixpkgs { inherit system;} ;
      in with pkgs;
      releaseTools.nixBuild {
	name = "cppi" ;
	src = tarball;
        inherit meta;
	buildInputs = [];
      };

    coverage =
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "cppi-coverage";
        src = tarball;
        inherit meta;
        buildInputs = [];
      };

  };

in jobs
