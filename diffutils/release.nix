{ nixpkgs ? ../../nixpkgs
, diffutils ? {outPath = ../../diffutils;}
, gnulib ? {outPath = ../../gnulib;}
}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [
  ];

  jobs = rec {

    tarball =
      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "diffutils-tarball";
        src = diffutils;

        autoconfPhase = ''
          mkdir -p ../gnulib
          cp -Rv ${gnulib}/* ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --skip-po --copy
        '';

        buildInputs = [
          git
          gettext
          cvs
          texinfo
          perl
          automake111x
          autoconf
          rsync
          gperf
          help2man
          xz
        ] ++ buildInputsFrom pkgs;
      };

    build =
      { system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "diffutils" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

    coverage =
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "diffutils-coverage";
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
        schedulingPriority = 50;
      };

  };

  
in jobs
