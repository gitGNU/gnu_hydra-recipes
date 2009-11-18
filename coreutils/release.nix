{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  gnulib = (import ../gnulib.nix) pkgs;

  buildInputsFrom = pkgs: with pkgs; [
    perl
  ];

  jobs = rec {

    tarball =
      { coreutilsSrc ? {outPath = ../../coreutils;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "coreutils-tarball";
        src = coreutilsSrc;

        buildInputs = [
          automake111x
          bison
          gettext
          git
          gperf
          texinfo
          rsync
          cvs
          xz
        ] ++ buildInputsFrom pkgs;

        dontBuild = false;         
        preConfigurePhases = "preAutoconfPhase autoconfPhase"; 
        preAutoconfPhase = ''
          cp -Rv ${gnulib}/* gnulib/
          export GNULIB_SRCDIR="`pwd`/gnulib"
          chmod -R 777 *


          sed 's|/usr/bin/perl|${perl}/bin/perl|' -i src/wheel-gen.pl
        '';
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in 
      pkgs.releaseTools.nixBuild {
        name = "coreutils" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.coverageAnalysis {
        name = "coreutils-coverage";
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

  };

  
in jobs
