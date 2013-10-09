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
, cpioSrc ? {outPath = ../../cpio;}
, paxutils ? {outPath = ../../paxutils;}
}:

let
  pkgs = import nixpkgs {};
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  meta = {
    homepage = http://www.gnu.org/software/cpio/;
    description = "GNU cpio, a program to create or extract from cpio archives";

    longDescription =
      '' GNU cpio copies files into or out of a cpio or tar archive.  The
         archive can be another file on the disk, a magnetic tape, or a pipe.

         GNU cpio supports the following archive formats: binary, old ASCII,
         new ASCII, crc, HPUX binary, HPUX old ASCII, old tar, and POSIX.1
         tar.  The tar format is provided for compatability with the tar
         program.  By default, cpio creates binary format archives, for
         compatibility with older cpio programs.  When extracting from
         archives, cpio automatically recognizes which kind of archive it is
         reading and can read archives created on machines with a different
         byte-order.
      '';

    license = "GPLv3+";

    maintainers = [ "Sergey Poznyakoff <gray@gnu.org.ua>" ];
  };

  succeedOnFailure = true;
  keepBuildDirectory = true;

in 
  import ../gnu-jobs.nix {
    name = "cpio";
    src  = cpioSrc;
    inherit nixpkgs meta;
    enableGnuCrossBuild = true;

    systems = ["x86_64-darwin" "i686-freebsd" "x86_64-linux" "i686-linux"];

    customEnv = {

      tarball = pkgs: {
        PAXUTILS_SRCDIR = paxutils;
        buildInputs = with pkgs; [ git texinfo bison cvs man rsync perl cpio automake111x xz gettext m4];
      } ;

    };
}

