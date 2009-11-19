{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [
  ];

  jobs = rec {

    tarball =
      { gnutarSrc ? {outPath = ../../gnutar;}
      , paxutils ? {outPath = ../../paxutils;}
      , gnulib ? {outPath = ../../gnulib;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "gnutar-tarball";
        src = gnutarSrc;

        autoconfPhase = ''
          cp -Rv ${gnulib} ../gnulib
          chmod -R 755 ../gnulib
          cp -Rv ${paxutils} ../paxutils
          chmod -R 755 ../paxutils

          ./bootstrap --gnulib-srcdir=../gnulib --paxutils-srcdir=../paxutils --skip-po --copy
        '';

        buildInputs = [
          git
          gettext
          cvs
          texinfo
          bison
          man 
          rsync
          perl
          cpio
        ] ++ buildInputsFrom pkgs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "gnutar" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

  };

  
in jobs
