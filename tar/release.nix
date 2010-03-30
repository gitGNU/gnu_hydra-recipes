{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs { system = "i686-linux"; };

  buildInputsFrom = pkgs: [ pkgs.gettext ];

  jobs = {

    tarball =
      { tarSrc ? {outPath = ../../tar;}
      , paxutils ? {outPath = ../../paxutils;}
      , gnulib ? {outPath = ../../gnulib;}
      }:

      pkgs.releaseTools.sourceTarball {
        name = "tar-tarball";
        src = tarSrc;

        autoconfPhase = ''
          # Disable Automake's `check-news' so that "make dist" always works.
          sed -i "configure.ac" -es/gnits/gnu/g

          cp -Rv ${gnulib} ../gnulib
          chmod -R 755 ../gnulib
          cp -Rv ${paxutils} ../paxutils
          chmod -R 755 ../paxutils

          ./bootstrap --gnulib-srcdir=../gnulib --paxutils-srcdir=../paxutils --skip-po --copy
        '';

        buildInputs = with pkgs;
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
        failureHook =
          '' if [ -f tests/testsuite.log ]
             then
                 echo
                 echo "build failed, dumping test log..."
                 cat tests/testsuite.log
             fi
          '';
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
