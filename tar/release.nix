{nixpkgs ? ../../nixpkgs}:
let
  # Build tarball and coverage analysis on i686, 
  # because x86_64 build fails at the moment.
  pkgs = import nixpkgs { system = "i686-linux"; };

  buildInputsFrom = pkgs: with pkgs; [
  ];

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

        # apply patch until it get's accepted upstream (http://www.mail-archive.com/bug-tar@gnu.org/msg02390.html)
        patches = [./tar-remote-shell-correction.patch]; 

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
      };

  };

  
in jobs
