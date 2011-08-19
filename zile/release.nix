/* Continuous integration of GNU with Hydra/Nix.
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

{ nixpkgs ? ../../nixpkgs 
, zile ? { outPath = ../../zile; }
}:

let
  meta = {
    description = "GNU Zile, a lightweight Emacs clone";

    longDescription = ''
      GNU Zile, which is a lightweight Emacs clone.  Zile is short
      for Zile Is Lossy Emacs.  Zile has been written to be as
      similar as possible to Emacs; every Emacs user should feel at
      home.

      Zile has all of Emacs's basic editing features: it is 8-bit
      clean (though it currently lacks Unicode support), and the
      number of editing buffers and windows is only limited by
      available memory and screen space respectively.  Registers,
      minibuffer completion and auto fill are available.  Function
      and variable names are identical with Emacs's (except those
      containing the word "emacs", which instead contain the word
      "zile"!).

      However, all of this is packed into a program which typically
      compiles to about 130Kb.
    '';

    homepage = http://www.gnu.org/software/zile/;

    license = "GPLv3+";

    maintainers = [
      "Reuben Thomas <rrt@sc3d.org>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

in
  import ../gnu-jobs.nix {
    name = "zile";
    src  = zile;
    inherit nixpkgs meta; 
    
    customEnv = {
        
      tarball = pkgs: {
        HELP2MAN = "${pkgs.help2man}/bin/help2man";
        buildInputs = with pkgs; [ ncurses help2man lua5 perl boehmgc m4 gitAndTools.git gitAndTools.git2cl gnugpg];
        dontBuild = false;
      } ;
      
      build = pkgs: ({
        TERM="xterm";
        buildInputs = with pkgs; [ncurses boehmgc];
      } // pkgs.lib.optionalAttrs (pkgs.stdenv.system == "i686-cygwin")  { NIX_LDFLAGS = "-lncurses"; } ) ;
      
      coverage = pkgs: {
        TERM="xterm";
        buildInputs = with pkgs; [ncurses boehmgc];
      };
      
    };   
  }


