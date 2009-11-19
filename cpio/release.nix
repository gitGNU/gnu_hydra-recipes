{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};
  gnulib = (import ../gnulib.nix) pkgs;
  paxutils = (import ../paxutils.nix) pkgs;

  buildInputsFrom = pkgs: with pkgs; [
  ];

  jobs = rec {

    tarball =
      { cpioSrc ? {outPath = ../../cpio;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "cpio-tarball";
        src = cpioSrc;

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
          man
          rsync
          gnum4
          bison
        ] ++ buildInputsFrom pkgs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "cpio" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

  };

in jobs
