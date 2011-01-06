/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009, 2010  Ludovic Courtès <ludo@gnu.org>
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

{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [ gettext_0_17 ];

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = rec {

    tarball =
      { libgpgerrorSrc ? { outPath = /data/src/libgpg-error; }
      }:

      releaseTools.makeSourceTarball {
	name = "libgpgerror-tarball";
	src = libgpgerrorSrc;

	buildInputs = (buildInputsFrom pkgs) ++ (with pkgs; [
	  autoconf automake111x libtool
	  subversion texinfo
	]);

        preAutoconf =
          '' # Remove Libtool-provided files to avoid any conflicts with the
             # version we're using here.
             rm -fv m4/libtool* m4/lt* libtool build-aux/lt*
             libtoolize --install --force
          '';

        inherit succeedOnFailure keepBuildDirectory;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "libgpgerror" ;
          src = tarball;
          buildInputs = buildInputsFrom pkgs;
          inherit succeedOnFailure keepBuildDirectory;
          
        };

  };

in jobs
