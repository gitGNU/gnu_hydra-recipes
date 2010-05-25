/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009  Ludovic Courtès <ludo@gnu.org>
   Copyright (C) 2009  Rob Vermaas <rob.vermaas@gmail.com>

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

{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [ perl help2man ];

  jobs = rec {

    tarball =
      { automakeSrc ? { outPath = ../../automake; }
      , autoconf ? pkgs.autoconf
      }:

      releaseTools.makeSourceTarball {
        name = "automake-tarball";
        src = automakeSrc;
        dontBuild = false;

        /* XXX: Automake says "version is incorrect" if you try to check its
           version number as is done below.  That's unfortunate.

        preConfigurePhases = "preAutoconfPhase autoconfPhase";
        preAutoconfPhase =
          ''sed -i "configure.ac" \
                -e "s/^AC_INIT(\([^,]\+\), \[\([^,]\+\)\]/AC_INIT(\1, [\2-$(git describe || echo git)]/g"
          '';
         */

        preConfigurePhases = "preAutoconfPhase autoconfPhase";
        preAutoconfPhase = "autoconf --version";
        bootstrapBuildInputs = [ autoconf ];
        buildInputs = (with pkgs; [ texinfo git ]) ++ (buildInputsFrom pkgs);
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , autoconf ? pkgs.autoconf
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "automake" ;
          src = tarball;
          buildInputs = [ autoconf ] ++ (buildInputsFrom pkgs);

          preConfigure = "autoconf --version";

          # Disable indented log output from Make, otherwise "make.test" will
          # fail.  Ask for verbose test suite output.
          preCheck = "unset NIX_INDENT_MAKE ; export VERBOSE=yes";
        };
  };

in jobs
