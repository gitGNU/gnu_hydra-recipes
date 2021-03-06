/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010, 2012  Ludovic Courtès <ludo@gnu.org>
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
, diffutils ? {outPath = ../../diffutils;}
}:
let
  pkgs = import nixpkgs {};

  meta = {
    homepage = http://www.gnu.org/software/diffutils/diffutils.html;
    description = "Commands for showing the differences between files (diff, cmp, etc.)";

    # Those who will receive email notifications.
    maintainers = [
      "Jim Meyering <jim@meyering.net>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];

  };

in
  import ../gnu-jobs.nix {
    name = "diffutils";
    src  = diffutils;
    inherit nixpkgs meta;

    systems = ["x86_64-darwin" "x86_64-linux" "i686-linux" "i686-solaris"];

    customEnv = {
      tarball = pkgs: {
	dontBuild = false;                        # to build `src/version.c'
	buildInputs = with pkgs; [
	  git
	  gettext_0_17
	  cvs
	  texinfo
	  perl
	  automake111x
	  autoconf
	  rsync
	  gperf
	  help2man
	  xz
	];
	patchPhase =
          # FIXME: Use the nice trick to avoid the absolute path.
	  '' sed -i "man/help2man" -e's|/usr/bin/perl|${pkgs.perl}/bin/perl|g'
	  '';
      };

      build = pkgs: {
        nativeBuildInputs = [ pkgs.xz ];
      };

      coverage = pkgs: {
        nativeBuildInputs = [ pkgs.xz ];
	meta = meta // { schedulingPriority = 50; };
      };

      xbuild_gnu = pkgs: {
        nativeBuildInputs = [ pkgs.xz ];
	meta = meta // { schedulingPriority = 10; };
      };
    };
  }
