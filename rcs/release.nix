/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2011-2014  Thien-Thi Nguyen
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
, rcs ? { outPath = ../../rcs; }
}:

let
  meta = {
    homepage = http://www.gnu.org/software/rcs/;
    description = "The Revision Control System (RCS) manages multiple revisions of files.";

    longDescription = ''
      The Revision Control System (RCS) manages multiple revisions of files.
      RCS automates the storing, retrieval, logging, identification, and merging
      of revisions. RCS is useful for text that is revised frequently, including
      source code, programs, documentation, graphics, papers, and form letters.
    '';

    license = "GPLv3+";

    # The value is in seconds.
    # These are low for now; we can relax them later if necessary.
    timeout = 600;
    maxSilent = 300;

    # Those who will receive email notifications.
    maintainers = [
      "Thien-Thi Nguyen <ttn@gnu.org>"
    ];
  };

  configureFlags = "";
in
  import ../gnu-jobs.nix {
    name = "rcs";
    src  = rcs;
    inherit nixpkgs meta;

    systems = ["x86_64-linux" "i686-linux" "x86_64-darwin"];

    customEnv = {

      tarball = pkgs: {
        buildInputs = with pkgs; [ automake autoconf ed texinfo emacs groff];
        autoconfPhase = ''
          export PATH=$PATH:../gnulib
          sh autogen.sh
        '';
        inherit configureFlags;
      } ;

      build = pkgs: {
        buildInputs = [pkgs.ed];
        inherit configureFlags;
      };

      coverage = pkgs: {
        buildInputs = [pkgs.ed];
        inherit configureFlags;
      };

    };
  }
