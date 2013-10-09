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

{ nixpkgs ? <nixpkgs>
, idutils ? { outPath = <idutils>; }
}:

let
  meta = {
    description = "GNU Idutils, a text searching utility";

    longDescription = ''
      An "ID database" is a binary file containing a list of file
      names, a list of tokens, and a sparse matrix indicating which
      tokens appear in which files.

      With this database and some tools to query it, many
      text-searching tasks become simpler and faster.  For example,
      you can list all files that reference a particular `\#include'
      file throughout a huge source hierarchy, search for all the
      memos containing references to a project, or automatically
      invoke an editor on all files containing references to some
      function or variable.  Anyone with a large software project to
      maintain, or a large set of text files to organize, can benefit
      from the ID utilities.

      Although the name `ID' is short for `identifier', the ID
      utilities handle more than just identifiers; they also treat
      other kinds of tokens, most notably numeric constants, and the
      contents of certain character strings.
    '';

    homepage = http://www.gnu.org/software/idutils/;
    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

in
  import ../gnu-jobs.nix {
    name = "idutils";
    src  = idutils;
    inherit nixpkgs meta;
    enableGnuCrossBuild = true;

    systems = ["x86_64-linux" "i686-linux" "i686-freebsd" "x86_64-darwin"];

    customEnv = {

      tarball = pkgs: {
        nativeBuildInputs = [ pkgs.xz ];
	buildInputs = with pkgs; [
	  automake111x
	  texinfo
	  gettext
	  git
	  gperf
	  bison
	  perl
	  rsync
	  help2man
	];
	dontBuild = false;
      };

      build = pkgs: {
        nativeBuildInputs = [ pkgs.xz ];
      };

      coverage = pkgs: {
        nativeBuildInputs = [ pkgs.xz ];
      };

      xbuild_gnu = pkgs: {
        nativeBuildInputs = [ pkgs.xz ];
      };

    };
  }
