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

{ nixpkgs ? ../../nixpkgs 
, cppi ? { outPath = ../../cppi ; rev = 1234; }
}:

let
  meta = {
    homepage = http://savannah.gnu.org/projects/cppi/;

    description = "GNU cppi, a cpp directive indenter";

    longDescription =
      '' GNU cppi indents C preprocessor directives to reflect their nesting
         and ensure that there is exactly one space character between each #if,
         #elif, #define directive and the following token.  The number of
         spaces between the `#' and the following directive must correspond
         to the level of nesting of that directive.
      '';

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [ 
      "Jim Meyering <jim@meyering.net>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

  buildFun = pkgs: {
    preHook = ''
      export src=$(ls $src/tarballs/*.tar.xz | sort | head -1)
    '';
    buildInputs = [pkgs.xz];
  };
in
  import ../gnu-jobs.nix {
    name = "cppi";
    src  = cppi;
    inherit nixpkgs meta;

    systems = ["x86_64-linux" "i686-linux" "x86_64-freebsd" "x86_64-darwin"];

    customEnv = {
      tarball = pkgs: {
        buildInputs = with pkgs; [ git texinfo bison cvs man rsync perl cpio automake111x xz gperf help2man gettext_0_18 flex];
        dontBuild = false;
      } ;
      build = buildFun;
      coverage = buildFun;
    };
  }
