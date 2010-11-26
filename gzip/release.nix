/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010  Ludovic Courtès <ludo@gnu.org>
   Copyright (C) 2010  Rob Vermaas <rob.vermaas@gmail.com>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

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
          automake111x
          texinfo
          gettext_0_17
          git 
          perl
          rsync
          xz
	];

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
	buildInputs = buildInputsFrom pkgs ++ lib.optional (system == "i686-cygwin") [pkgs.ncurses]; 
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
