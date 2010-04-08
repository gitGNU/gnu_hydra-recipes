{ nixpkgs ? ../../nixpkgs 
, gzip ? { outPath = ../../gzip; }
, gnulib ? {outPath = ../../gnulib;}
}:

let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs;
    [ utillinuxngCurses # more(1), for zmore's unit tests
      less              # less(1), for zless's unit tests
    ];

  jobs = rec {

    tarball =
      pkgs.releaseTools.sourceTarball {
	name = "gzip-tarball";
	src = gzip;

        autoconfPhase = ''
          mkdir -p ../gnulib
          cp -Rv "${gnulib}/"* ../gnulib
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
	];
      };

    build =
      { system ? "x86_64-linux"
      }:
      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
	name = "gzip" ;
	src = tarball;
	buildInputs = buildInputsFrom pkgs;
      };

    coverage =
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "gzip-coverage";
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

  };

in jobs
