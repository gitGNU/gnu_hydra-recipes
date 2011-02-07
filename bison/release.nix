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
, bison ? { outPath = ../../bison; }
}:

let
  meta = {
    description = "GNU Bison, a Yacc-compatible parser generator";

    longDescription = ''
      Bison is a general-purpose parser generator that converts an
      annotated context-free grammar into an LALR(1) or GLR parser for
      that grammar.  Once you are proficient with Bison, you can use
      it to develop a wide range of language parsers, from those used
      in simple desk calculators to complex programming languages.

      Bison is upward compatible with Yacc: all properly-written Yacc
      grammars ought to work with Bison with no change.  Anyone
      familiar with Yacc should be able to use Bison with little
      trouble.  You need to be fluent in C or C++ programming in order
      to use Bison.
    '';

    homepage = http://www.gnu.org/software/bison/;

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

in 
  import ../gnu-jobs.nix {
    name = "bison";
    src  = bison;
    inherit nixpkgs meta; 
    enableGnuCrossBuild = true;

    customEnv = {
        
      tarball = pkgs: {
        postUnpack = ''
          sed -i "s|/usr/bin/perl|${pkgs.perl}/bin/perl|" */etc/prefix-gnulib-mk 
          # temp remove until fixed upstream
          sed -i "s|lib/pipe.c||" */po/POTFILES.in
        '';
        buildInputs = with pkgs; [
          automake111x
          texinfo
          gettext
          git 
          flex
          perl
          rsync
          xz
          help2man
        ];
        dontBuild = false;
      } ;
 
      build = pkgs: {
        buildInputs = [pkgs.m4 pkgs.perl];
      };      

      coverage = pkgs: {
        buildInputs = [pkgs.m4 pkgs.perl];
        succeedOnFailure = true;
        keepBuildDirectory = true;
      };      

      xbuild_gnu = pkgs: {
        buildInputs = [pkgs.m4];
      };      
    };   
  }

