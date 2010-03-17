{ nixpkgs ? ../../nixpkgs 
, grep ? { outPath = ../../grep; }
, gnulib ? {outPath = ../../gnulib;}
}:

let
  pkgs = import nixpkgs {};

  meta = {
    homepage = http://www.gnu.org/software/grep/;
    description = "GNU implementation of the Unix grep command";

    longDescription = ''
      The grep command searches one or more input files for lines
      containing a match to a specified pattern.  By default, grep
      prints the matching lines.
    '';

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [
      "Jim Meyering <jim@meyering.net>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

  jobs = rec {

    tarball =
      pkgs.releaseTools.makeSourceTarball {
	name = "grep-tarball";
	src = grep;
        inherit meta;

        autoconfPhase = ''
          mkdir -p ../gnulib
          cp -Rv ${gnulib}/* ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --skip-po --copy
        '';

	buildInputs = with pkgs; [
          automake111x
          pkgconfig
          texinfo
          gettext
          git 
          perl
          rsync
          xz
          cvs
	];
      };

    build =
      { system ? "x86_64-linux"
      }:
      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
	name = "grep" ;
	src = tarball;
        inherit meta;
	buildInputs = [];
      };

    coverage =
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "grep-coverage";
        src = tarball;
        inherit meta;
        buildInputs = [];
      };

  };

in jobs
