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
}:

let
  pkgs = import nixpkgs {};

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

    # Those who will receive email notifications.
    maintainers = [
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };

  configureFlags = "RCS_PRETEST=acknowledged";

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = rec {

    tarball = 
      { rcs ? { outPath = ../../rcs; }
      , gnulib ? {outPath = ../../gnulib;}
      }:
      pkgs.releaseTools.makeSourceTarball {
	name = "rcs-tarball";
	src = rcs;
        inherit meta configureFlags succeedOnFailure keepBuildDirectory;
        autoconfPhase = ''
          cp -Rv ${gnulib} ../gnulib
          chmod -R a+rwx ../gnulib
          export PATH=$PATH:../gnulib
          sh autogen.sh
        '';
        buildInputs = with pkgs; [ automake111x autoconf ed texinfo emacs];
      };

    build =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball {}
      }:
      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "rcs" ;
        src = tarball;
        inherit meta configureFlags succeedOnFailure keepBuildDirectory;

        buildInputs = with pkgs; [ed];

        succeedOnFailure = true;
        keepBuildDirectory = true;
      } ;

    coverage =
      { tarball ? jobs.tarball {}
      }:
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "rcs-coverage";
        src = tarball;
        inherit meta configureFlags;
        buildInputs = with pkgs; [ed];
      };

  };

in jobs
