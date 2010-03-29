{ nixpkgs ? ../../nixpkgs 
}:

let
  meta = {
    description = "GNU Zile, a lightweight Emacs clone";

    longDescription = ''
      GNU Zile, which is a lightweight Emacs clone.  Zile is short
      for Zile Is Lossy Emacs.  Zile has been written to be as
      similar as possible to Emacs; every Emacs user should feel at
      home.

      Zile has all of Emacs's basic editing features: it is 8-bit
      clean (though it currently lacks Unicode support), and the
      number of editing buffers and windows is only limited by
      available memory and screen space respectively.  Registers,
      minibuffer completion and auto fill are available.  Function
      and variable names are identical with Emacs's (except those
      containing the word "emacs", which instead contain the word
      "zile"!).

      However, all of this is packed into a program which typically
      compiles to about 130Kb.
    '';

    homepage = http://www.gnu.org/software/zile/;

    license = "GPLv3+";

    maintainers = [
      "Reuben Thomas <rrt@sc3d.org>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

  pkgs = import nixpkgs {};

  jobs = rec {

    tarball = 
      { zile ? { outPath = ../../zile; }
      , gnulib ? { outPath = ../../gnulib; }
      }: 
      with pkgs;
      releaseTools.makeSourceTarball {
	name = "zile-tarball";
	src = zile;
        inherit meta;

        dontBuild = false;

        autoconfPhase = ''
          mkdir -p ../gnulib
          cp -Rv ${gnulib}/* ../gnulib
          chmod -R 755 ../gnulib
          export GNULIB_SRCDIR=../gnulib
          ./autogen.sh
        '';

        HELP2MAN = "${help2man}/bin/help2man";
	buildInputs = [
          ncurses
          help2man
          lua5
	];
      };

    build =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball {}
      }:
      let pkgs = import nixpkgs { inherit system;} ;
      in with pkgs;
      releaseTools.nixBuild {
	name = "zile" ;
	src = tarball;
        inherit meta;
        TERM="xterm";
	buildInputs = [ncurses];
      };

    coverage =
      { tarball ? jobs.tarball {} }:
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "zile-coverage";
        src = tarball;
        inherit meta;
        TERM="xterm";
        buildInputs = [ncurses];
      };

  };

in jobs
