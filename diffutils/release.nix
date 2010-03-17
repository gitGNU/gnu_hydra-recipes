{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [
  ];

  jobs = rec {

    tarball =
      { diffutilsSrc ? {outPath = ../../diffutils;}
      , gnulib ? {outPath = ../../gnulib;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "diffutils-tarball";
        src = diffutilsSrc;

        autoconfPhase = ''
          cp -Rv ${gnulib}/* gnulib/
          chmod -R 755 gnulib

          ./bootstrap --gnulib-srcdir=./gnulib --skip-po --copy
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
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "diffutils" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

  };

  
in jobs
