{ nixpkgs ? ../../nixpkgs 
, gzip ? { outPath = ../../gzip; }
, gnulib ? {outPath = ../../gnulib;}
}:

let
  pkgs = import nixpkgs {};

  jobs = with pkgs; rec {

    tarball =
      pkgs.releaseTools.makeSourceTarball {
	name = "gzip-tarball";
	src = gzip;

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
          xz
	];
      };

    build =
      { system ? "x86_64-linux"
      }:

      releaseTools.nixBuild {
	name = "gzip" ;
	src = tarball;
	buildInputs = [];
      };

    coverage =
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "gzip-coverage";
        src = tarball;
        buildInputs = [];
      };

  };

in jobs
