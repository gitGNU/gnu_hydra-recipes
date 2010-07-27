/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009, 2010  Ludovic Courtès <ludo@gnu.org>
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

  buildInputsFrom = pkgs: with pkgs; [ perl m4 ];

  jobs = rec {

    tarball =
      { autoconfSrc ? {outPath = ../../autoconf;}
      }:

      with pkgs;

      pkgs.releaseTools.sourceTarball {
        name = "autoconf-tarball";
        src = autoconfSrc;
        preConfigurePhases = "preAutoconfPhase autoconfPhase";
        preAutoconfPhase = ''
          echo -n "$(git describe)" > .tarball-version
        '';

        # Autoconf needs a version of itself to bootstrap, along with
        # `aclocal' from Automake.
        bootstrapBuildInputs = [ autoconf automake111x ];
        buildInputs = [
          texinfo
          help2man
          git
        ] ++ buildInputsFrom pkgs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "autoconf" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      pkgs.releaseTools.nixBuild {
        name = "autoconf-manual";
        src = tarball;
        buildInputs = [ pkgs.texinfo pkgs.texLive ] ++ (buildInputsFrom pkgs);

        buildPhase = "make html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/autoconf/autoconf.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/autoconf/autoconf.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };
  };

in jobs
