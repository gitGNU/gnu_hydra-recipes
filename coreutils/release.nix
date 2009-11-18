{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  gnulib = pkgs.fetchgit {
    url = git://git.savannah.gnu.org/gnulib.git;
    rev = "6038ee4b827caaf05fa37dbb2304fedb9d0cd6c7";
    sha256 = "8d13d4dcd6cde4ca5f91fa6aff90205ded691cfaa30d436348389a2280018b11";
  };

  buildInputs = with pkgs; [
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
        ] ++ buildInputs;

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

      with import nixpkgs {inherit system;};

      releaseTools.nixBuild rec {
        name = "coreutils" ;
        src = tarball;
        inherit buildInputs;
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.coverageAnalysis {
        name = "coreutils-coverage";
        src = tarball;
        inherit buildInputs;
      };

  };

  
in jobs
