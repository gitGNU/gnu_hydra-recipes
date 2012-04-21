/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010, 2012  Ludovic Courtès <ludo@gnu.org>
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

{ nixpkgs ? { outPath = ../../nixpkgs; }
, gnulib ? { outPath = ../../gnulib; }
, findutilsSrc ? { outPath = ../../findutils; } }:

let
  pkgs = import nixpkgs {};

  meta = {
    description = "GNU Findutils, a program to find files";

    longDescription =
      '' The GNU Find Utilities are the basic directory searching utilities
         of the GNU operating system. These programs are typically used in
         conjunction with other programs to provide modular and powerful
         directory search and file locating capabilities to other commands.
      '';

    homepage = http://savannah.gnu.org/projects/findutils;

    license = "GPLv3+";

    maintainers = [ "James Youngman <jay@gnu.org>" ];
  };

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = {
    tarball =
      with pkgs;
      releaseTools.sourceTarball {
	name = "findutils-tarball";
	src = findutilsSrc;
	buildInputs =
          [ automake111x gettext gperf bison groff git
            texinfo xz
            cvs # for `autopoint'
          ];
	autoconfPhase =
          # `gnulib-tool' wants write access to the Gnulib directory, e.g.,
          # to create `./build-aux/arg-nonnull.h.tmp'.  Thus we have to copy
          # the whole Gnulib tree in a writable place.
	  '' cp -rv "${gnulib}" ../gnulib
             chmod -R u+w ../gnulib
             sh ./import-gnulib.sh -d ../gnulib
	  '';
        inherit meta succeedOnFailure keepBuildDirectory;
      };

    build =
      { system ? builtins.currentSystem
      , tarball ? jobs.tarball }:

      let pkgs = import nixpkgs { inherit system; };
      in
	pkgs.releaseTools.nixBuild {
	  name = "findutils";
	  src = tarball;

          # XXX: Work around build failures of Expect, Tk, Freetype, etc. on
          # non-GNU platforms.
          buildInputs = with pkgs;
            (stdenv.lib.optional stdenv.isLinux dejagnu);
        inherit meta succeedOnFailure keepBuildDirectory;
	};

    coverage =
      { tarball ? jobs.tarball }:

      let pkgs = import nixpkgs {};
      in
	pkgs.releaseTools.coverageAnalysis {
	  name = "findutils-coverage";
	  src = tarball;
          buildInputs = [ pkgs.dejagnu ];
	};
  };
in
  jobs
