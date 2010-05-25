/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010  Ludovic Courtès <ludo@gnu.org>

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

{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [ readline bison ];

  jobs = rec {

    tarball =
      { bashSrc }:

      releaseTools.sourceTarball {
	name = "bash-tarball";
	src = bashSrc;

        patches = [ ./interpreter-path.patch ];

        # The generated files are checked in.
        autoconfPhase = "true";

        distPhase =
          # Bash doesn't use Automake.  The makefile says one should use the
          # `support/mkdist' script but that script doesn't exist.
          ''
             version="4.1-$(cat .git/refs/remotes/origin/master | cut -c 1-8)"

             mkdir "bash-$version"
             for dir in `cat MANIFEST |grep -v '^#' | grep -v '[[:blank:]]\+f' | sed -es'/[[:blank:]]\+d.*//g'`
             do
               mkdir -v "bash-$version/$dir"
             done
             for file in `cat MANIFEST |grep -v '^#' | grep -v '[[:blank:]]\+d' | sed -es'/[[:blank:]]\+f.*//g'`
             do
               cp -pv "$file" "bash-$version/$file"
             done

             mkdir -p "$out/tarballs"
             GZIP=--best tar czf "$out/tarballs/bash-$version.tar.gz" "bash-$version"
          '';

        doCheck = false;
	buildInputs = (buildInputsFrom pkgs);
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "bash";
          src = tarball;
          buildInputs = buildInputsFrom pkgs;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "bash-coverage";
	src = tarball;
	buildInputs = buildInputsFrom pkgs;
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.nixBuild {
        name = "bash-manual";
        src = tarball;
        buildInputs = (buildInputsFrom pkgs)
          ++ [ pkgs.texinfo pkgs.texLive pkgs.perl
               pkgs.groff pkgs.ghostscript ];

        buildPhase = "make -C doc html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install
             cp -v doc/bashref.{pdf,html} "$out/share/doc/bash"

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/bash/bashref.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/bash/bashref.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };
  };

in jobs
