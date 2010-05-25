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

{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [
  ];

  jobs = rec {

    tarball =
      { cpioSrc ? {outPath = ../../cpio;}
      , paxutils ? {outPath = ../../paxutils;}
      , gnulib ? {outPath = ../../gnulib;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "cpio-tarball";
        src = cpioSrc;

        autoconfPhase = ''
          cp -Rv ${gnulib} ../gnulib
          chmod -R 755 ../gnulib
          cp -Rv ${paxutils} ../paxutils
          chmod -R 755 ../paxutils

          ./bootstrap --gnulib-srcdir=../gnulib --paxutils-srcdir=../paxutils --skip-po --copy
        '';

        buildInputs = [
          git
          gettext
          cvs
          texinfo
          man
          rsync
          gnum4
          bison
          automake111x
        ] ++ buildInputsFrom pkgs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "cpio" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

  };

in jobs
