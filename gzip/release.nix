{ nixpkgs ? ../../nixpkgs 
, gzip ? { outPath = ../../gzip; }
, gnulib ? {outPath = ../../gnulib;}
}:

let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs;
    # less(1), for zless's unit tests
    [ less ] ++

    # more(1), for zmore's unit tests.  Assume it's available on non-Linux
    # platforms.
    (stdenv.lib.optional stdenv.isLinux utillinuxngCurses);

  meta = {
   homepage = http://www.gnu.org/software/gzip/;
    description = "Gzip, the GNU zip compression program";

    longDescription =
      ''gzip (GNU zip) is a popular data compression program written by
        Jean-loup Gailly for the GNU project.  Mark Adler wrote the
        decompression part.

        We developed this program as a replacement for compress because of
        the Unisys and IBM patents covering the LZW algorithm used by
        compress.  These patents made it impossible for us to use compress,
        and we needed a replacement.  The superior compression ratio of gzip
        is just a bonus.
      '';

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [
      "Jim Meyering <jim@meyering.net>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

  jobs = rec {

    tarball =
      pkgs.releaseTools.sourceTarball {
	name = "gzip-tarball";
	src = gzip;

        autoconfPhase = ''
          mkdir -p ../gnulib
          cp -Rv "${gnulib}/"* ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --skip-po --copy
        '';

	buildInputs = with pkgs; [
          texinfo
          gettext
          git 
          perl
          rsync
          xz
	];
        automake = pkgs.automake111x;
        inherit meta;
      };

    build =
      { system ? "x86_64-linux"
      }:
      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
	name = "gzip" ;
	src = tarball;
	buildInputs = buildInputsFrom pkgs;
        inherit meta;
      };

    coverage =
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "gzip-coverage";
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
        inherit meta;
      };

  };

in jobs
