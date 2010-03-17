{ nixpkgs ? ../../nixpkgs 
, cppi ? { outPath = ../../cppi; }
, gnulib ? {outPath = ../../gnulib;}
}:

let
  pkgs = import nixpkgs {};

  jobs = with pkgs; rec {

    tarball =
      pkgs.releaseTools.makeSourceTarball {
	name = "cppi-tarball";
	src = cppi;

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

      releaseTools.nixBuild {
	name = "cppi" ;
	src = tarball;
	buildInputs = [];
      };

    coverage =
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "cppi-coverage";
        src = tarball;
        buildInputs = [];
      };

  };

in jobs
