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

{ nixpkgs ? ../../nixpkgs
, tarSrc ? {outPath = ../../tar;}
, paxutils ? {outPath = ../../paxutils;}
}:
let
  buildInputsFrom = pkgs: [ pkgs.gettext_0_18 ];
  meta = {
    homepage = http://www.gnu.org/software/tar/;
    description = "GNU implementation of the `tar' archiver";

    longDescription = ''
      The Tar program provides the ability to create tar archives, as
      well as various other kinds of manipulation.  For example, you
      can use Tar on previously created archives to extract files, to
      store additional files, or to update or list files which were
      already stored.

      Initially, tar archives were used to store files conveniently on
      magnetic tape.  The name "Tar" comes from this use; it stands
      for tape archiver.  Despite the utility's name, Tar can direct
      its output to available devices, files, or other programs (using
      pipes), it can even access remote devices or files (as
      archives).
    '';

    license = "GPLv3+";

    maintainers = [];
  };

in
  import ../gnu-jobs.nix {
    name = "tar";
    src  = tarSrc;
    inherit nixpkgs meta; 
    enableGnuCrossBuild = true;

    systems = ["x86_64-darwin" "i686-linux" "x86_64-linux"];
    
    customEnv = {
        
      tarball = pkgs: {
        PAXUTILS_SRCDIR = paxutils;
          
        autoconfPhase = ''
          # Disable Automake's `check-news' so that "make dist" always works.
          sed -i "configure.ac" -es/gnits/gnu/g

          ./bootstrap --gnulib-srcdir=../gnulib --skip-po --copy
        '';
        buildInputs = with pkgs; [ git texinfo bison cvs man rsync perl cpio automake111x xz ] ++ buildInputsFrom pkgs;
      } ;
      
      build = pkgs: {
        buildInputs = buildInputsFrom pkgs;
      };
      
      coverage = pkgs: {
        buildInputs = buildInputsFrom pkgs;
        schedulingPriority = 50;
      };
      
    };   
  }
