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
, patchSrc ? { outPath = ../../patch; } }:

let
  meta = {
    description = "GNU Patch, a program to apply differences to files";

    longDescription =
      '' GNU Patch takes a patch file containing a difference listing
         produced by the diff program and applies those differences to one or
         more original files, producing patched versions.
      '';

    homepage = http://savannah.gnu.org/projects/patch;

    license = "GPLv3+";

    maintainers = [ "Andreas Gruenbacher <agruen@gnu.org>" ];
  };
in
  import ../gnu-jobs.nix {
    name = "patch";
    src  = patchSrc;
    inherit nixpkgs meta; 
    enableGnuCrossBuild = true;
    
    customEnv = {
        
      tarball = pkgs: {
        buildInputs = with pkgs; [ git xz gettext_0_17 texinfo automake111x bison]; # the `testing' branch needs it
      } ;
      
    };   
  }
