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
}:

let
  meta = {
    homepage = http://savannah.gnu.org/projects/cppi/;

    description = "GNU cppi, a cpp directive indenter";

    longDescription =
      '' GNU cppi indents C preprocessor directives to reflect their nesting
         and ensure that there is exactly one space character between each #if,
         #elif, #define directive and the following token.  The number of
         spaces between the `#' and the following directive must correspond
         to the level of nesting of that directive.
      '';

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [ 
      "Jim Meyering <jim@meyering.net>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

  pkgs = import nixpkgs {};

  jobs = rec {

    tarball = 
      { cppi ? { outPath = ../../cppi; }
      , gnulib ? {outPath = ../../gnulib;}
      }: 
      with pkgs;
      releaseTools.makeSourceTarball {
	name = "cppi-tarball";
	src = cppi;
        inherit meta;

        autoconfPhase = ''
          mkdir -p ../gnulib
          cp -Rv ${gnulib}/* ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --skip-po --copy
        '';

	buildInputs = [
          automake111x
          texinfo
          gettext_0_17
          git 
          wget
          perl
          rsync
          flex2535
          help2man
          gperf
          cvs
	];
      };

    build =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball {}
      }:
      let pkgs = import nixpkgs { inherit system;} ;
      in with pkgs;
      releaseTools.nixBuild {
	name = "cppi" ;
	src = tarball;
        inherit meta;
	buildInputs = [];
      };

    coverage =
      { tarball ? jobs.tarball {} }:
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "cppi-coverage";
        src = tarball;
        inherit meta;
        buildInputs = [];
      };

  };

in jobs
