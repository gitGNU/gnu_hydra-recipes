/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010-2012  Ludovic Courtès <ludo@gnu.org>
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
, bison ? { outPath = ../../bison; rev = "1234"; }
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
      "Akim Demaille <akim@lrde.epita.fr>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

  m4 = pkgs : with pkgs; lib.overrideDerivation pkgs.m4 (args: { 
    name = "m4-1.4.16";
    src = fetchurl {
      url = mirror://gnu/m4/m4-1.4.16.tar.bz2;
      sha256 = "035r7ma272j2cwni2961jp22k6bn3n9xwn3b3qbcn2yrvlghql22";
    };
  });
in 
  import ../gnu-jobs.nix {
    name = "bison";
    src  = bison;
    inherit nixpkgs meta; 
    systems = ["x86_64-linux" "i686-linux" "x86_64-darwin"];
    customEnv = {
        
      tarball = pkgs: {
        postUnpack = ''
          if [[ -f $sourceRoot/etc/prefix-gnulib-mk ]]; then
            sed -i "s|/usr/bin/perl|${pkgs.perl}/bin/perl|" $sourceRoot/etc/prefix-gnulib-mk 

          fi
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
          (m4 pkgs)
          graphviz
        ];
        dontBuild = false;
      } ;
 
      build = pkgs: {
        buildInputs = [(m4 pkgs) pkgs.perl pkgs.flex];
      };      

      coverage = pkgs: {
        buildInputs = [(m4 pkgs) pkgs.perl pkgs.flex];
        succeedOnFailure = true;
        keepBuildDirectory = true;
      };      

    };   
  }

