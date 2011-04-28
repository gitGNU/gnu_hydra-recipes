/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010  Ludovic Courtès <ludo@gnu.org>
   Copyright (C) 2011  Rob Vermaas <rob.vermaas@gmail.com>

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
, emacs ? { outPath = ../../emacs; }
}:

let
  meta = {
    description = "GNU Emacs 24.x, the extensible, customizable text editor";

    longDescription = ''
      GNU Emacs is an extensible, customizable text editor—and more.  At its
      core is an interpreter for Emacs Lisp, a dialect of the Lisp
      programming language with extensions to support text editing.

      The features of GNU Emacs include: content-sensitive editing modes,
      including syntax coloring, for a wide variety of file types including
      plain text, source code, and HTML; complete built-in documentation,
      including a tutorial for new users; full Unicode support for nearly all
      human languages and their scripts; highly customizable, using Emacs
      Lisp code or a graphical interface; a large number of extensions that
      add other functionality, including a project planner, mail and news
      reader, debugger interface, calendar, and more.  Many of these
      extensions are distributed with GNU Emacs; others are available
      separately.
    '';

    homepage = http://www.gnu.org/software/emacs/;
    license = "GPLv3+";
  };

in
  import ../gnu-jobs.nix {
    name = "emacs";
    src  = emacs;
    inherit nixpkgs meta; 
    enableGnuCrossBuild = true;
    useLatestGnulib = false;    
    customEnv = {
        
      tarball = pkgs: {
        configureFlags ="--with-crt-dir=${pkgs.stdenv.glibc}/lib" ;
        buildInputs = with pkgs; [ texinfo ncurses bazaar];

        autoconfPhase = '' 
          ./autogen.sh
        '';

        preConfigure = ''
          for i in Makefile.in ./src/Makefile.in ./lib-src/Makefile.in ./leim/Makefile.in; do
            substituteInPlace $i --replace /bin/pwd pwd
          done
        '';

        distPhase = ''  
          make bootstrap
          ./make-dist --tar
          ensureDir $out/tarballs
          cp -pvd *.tar.gz $out/tarballs
        '';
      } ;

      build = pkgs: {
        buildInputs = with pkgs; [ texinfo ncurses ];
        configureFlags ="--with-crt-dir=${pkgs.stdenv.glibc}/lib" ;
      };      
      
      coverage = build;
    };   
  }
