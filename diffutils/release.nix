{ nixpkgs ? ../../nixpkgs
}:
let
  pkgs = import nixpkgs {};

  meta = {
    homepage = http://www.gnu.org/software/diffutils/diffutils.html;
    description = "Commands for showing the differences between files (diff, cmp, etc.)";

    # Those who will receive email notifications.
    maintainers = [
      "Jim Meyering <jim@meyering.net>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];

  };

  jobs = rec {

    tarball = 
      { diffutils ? {outPath = ../../diffutils;}
      , gnulib ? {outPath = ../../gnulib;}
      }:
      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "diffutils-tarball";
        src = diffutils;
        inherit meta;

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
        ] ;
      };

    build =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball {}
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "diffutils" ;
        src = tarball;
        inherit meta;
        buildInputs = [];
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "diffutils-coverage";
        src = tarball;
        inherit meta;
        buildInputs = [];
        schedulingPriority = 50;
      };

  };

  
in jobs
