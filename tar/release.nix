{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: [ pkgs.gettext ];

  jobs = rec {

    tarball =
      { tarSrc ? {outPath = ../../tar;}
      , paxutils ? {outPath = ../../paxutils;}
      , gnulib ? {outPath = ../../gnulib;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "tar-tarball";
        src = tarSrc;

        autoconfPhase = ''
          cp -Rv ${gnulib} ../gnulib
          chmod -R 755 ../gnulib
          cp -Rv ${paxutils} ../paxutils
          chmod -R 755 ../paxutils

          ./bootstrap --gnulib-srcdir=../gnulib --paxutils-srcdir=../paxutils --skip-po --copy
        '';

        buildInputs =
         [ git texinfo bison
           cvs # for `autopoint'
           man rsync perl cpio automake111x
         ] ++ buildInputsFrom pkgs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "tar" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.coverageAnalysis {
        name = "tar-coverage";
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
        schedulingPriority = 50;
      };

  };

in jobs
