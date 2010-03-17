{ nixpkgs ? ../../nixpkgs 
, grep ? { outPath = ../../gzip; }
, gnulib ? {outPath = ../../gnulib;}
}:

let
  pkgs = import nixpkgs {};

  jobs = rec {

    tarball =
      pkgs.releaseTools.makeSourceTarball {
	name = "grep-tarball";
	src = grep;

        autoconfPhase = ''
          mkdir -p ../gnulib
          cp -Rv ${gnulib}/* ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --skip-po --copy
        '';

	buildInputs = with pkgs; [
          automake111x
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
	buildInputs = [];
      };

    coverage =
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "grep-coverage";
        src = tarball;
        buildInputs = [];
      };

  };

in jobs
