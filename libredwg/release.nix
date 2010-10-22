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

{ nixpkgs ? { outPath = ../../nixpkgs; }
, libredwgSrc ? { outPath = ../../libredwg; } }:

let
  pkgs = import nixpkgs {};

  meta = {
    description = "GNU LibreDWG, a free C library to handle DWG files.";

    longDescription =
      '' GNU LibreDWG is a free C library to handle DWG files. It aims to be a free 
         replacement for the OpenDWG libraries. DWG is the native file format of AutoCAD. 
      '';

    homepage = http://www.gnu.org/software/libredwg/;

    license = "GPLv3+";

    maintainers =
     [ 
     ];
  };

  jobs = {
    tarball =
      with pkgs;
      releaseTools.sourceTarball {
        name = "libredwg";
        src = libredwgSrc;
        buildInputs =
          [ gettext texinfo automake111x python swig
          ];
        inherit meta;
      };

    build =
      { system ? builtins.currentSystem
      , tarball ? jobs.tarball }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "libredwg";
          src = tarball;
          inherit meta;
        };

    coverage =
      { tarball ? jobs.tarball }:

      let pkgs = import nixpkgs {};
      in
        pkgs.releaseTools.coverageAnalysis {
          name = "libredwg-coverage";
          src = tarball;
        };
  };
in
  jobs
