/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009, 2010  Ludovic Courtès <ludo@gnu.org>
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

{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs { system = "i686-linux"; };
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  buildInputsFrom = pkgs: [ pkgs.gettext_0_18 ];

  jobs = {

    tarball =
      { tarSrc ? {outPath = ../../tar;}
      , gnulib ? {outPath = ../../gnulib;}
      , paxutils ? {outPath = ../../paxutils;}
      }:

      pkgs.releaseTools.sourceTarball {
        name = "tar-tarball";
        src = tarSrc;

        PAXUTILS_SRCDIR = paxutils;
        autoconfPhase = ''
          # Disable Automake's `check-news' so that "make dist" always works.
          sed -i "configure.ac" -es/gnits/gnu/g

          cp -Rv ${gnulib} ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --skip-po --copy
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

    xbuild_gnu =
      # Cross build to GNU.
      { tarball ? jobs.tarball {}
      }:

      let pkgs = import nixpkgs {
            crossSystem = crossSystems.i586_pc_gnu;
          };
      in
      (pkgs.releaseTools.nixBuild {
        name = "tar" ;
        src = tarball;
        doCheck = false;
      }).hostDrv;

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
