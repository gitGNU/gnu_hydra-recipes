/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010  Ludovic Courtès <ludo@gnu.org>
   Copyright (C) 2009, 2010  Rob Vermaas <rob.vermaas@gmail.com>

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

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = rec {

    tarball = 
      { diffutils ? {outPath = ../../diffutils;}
      , gnulib ? {outPath = ../../gnulib;}
      }:
      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "diffutils-tarball";
        src = diffutils;
        inherit meta succeedOnFailure keepBuildDirectory;

        autoconfPhase = ''
          mkdir -p ../gnulib
          cp -Rv ${gnulib}/* ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --skip-po --copy
        '';

        buildInputs = [
          git
          gettext_0_17
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
        inherit meta succeedOnFailure keepBuildDirectory;
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
