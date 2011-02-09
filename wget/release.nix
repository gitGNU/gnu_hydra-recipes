/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010-2011  Ludovic Courtès <ludo@gnu.org>
   Copyright (C) 2010-2011  Rob Vermaas <rob.vermaas@gmail.com>

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
, wget ? { outPath = ../../wget; }
}:

let
  meta = {
    # Those who will receive email notifications.
    maintainers = [
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

in 
  import ../gnu-jobs.nix {
    name = "wget";
    src  = wget;
    inherit nixpkgs meta; 

    customEnv = {
        
      tarball = pkgs: {
        buildInputs = with pkgs; [
          automake111x
          texinfo
          gettext_0_17
          bazaar 
          git
          cvs
          bison
          perl
          rsync
          xz
          help2man
          flex
        ];
      } ;

      build = pkgs: {
        buildInputs = [pkgs.gnutls];
        configureFlags = "--with-ssl=gnutls";
      };      
    };   
  }

