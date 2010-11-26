/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009, 2010  Ludovic Courtès <ludo@gnu.org>
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

{ nixpkgs ? ../../nixpkgs }:

let
  meta = {
    description = "GNU Libgcrypt, a general-pupose cryptographic library";

    longDescription = ''
      GNU Libgcrypt is a general purpose cryptographic library based on
      the code from GnuPG.  It provides functions for all
      cryptographic building blocks: symmetric ciphers, hash
      algorithms, MACs, public key algorithms, large integer
      functions, random numbers and a lot of supporting functions.
    '';

    license = "LGPLv2+";

    homepage = http://gnupg.org/;

    # Those who will receive email notifications.
    maintainers = [ "hydra-logs@gnupg.org" ];
  };

  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs;
    # On Darwin libintl is needed.
    stdenv.lib.optional stdenv.isDarwin gettext_0_17;

  jobs = rec {

    tarball =
      { libgcryptSrc ? { outPath = ../../libgcrypt; }
      , libgpgerror ? pkgs.libgpgerror
      }:

      releaseTools.makeSourceTarball {
	name = "libgcrypt-tarball";
	src = libgcryptSrc;

	buildInputs = (buildInputsFrom pkgs)
          ++ [ libgpgerror ]
          ++ (with pkgs; [
	       autoconf automake111x
               libtool_1_5 # the repo contains Libtool 1.5's `ltmain.sh', etc.
	       subversion texinfo transfig ghostscript
	      ]);

        inherit meta;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , libgpgerror ? pkgs.libgpgerror
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "libgcrypt";
          src = tarball;
          buildInputs = (buildInputsFrom pkgs);
          propagatedBuildInputs = [ libgpgerror ];
          inherit meta;
        };

    coverage =
      { tarball ? jobs.tarball {}
      , libgpgerror ? pkgs.libgpgerror
      }:

      releaseTools.coverageAnalysis {
	name = "libgcrypt-coverage";
	src = tarball;
	buildInputs = (buildInputsFrom (import nixpkgs {})) ++ [ libgpgerror ];
        inherit meta;
      };

    manual =
      { tarball ? jobs.tarball {}
      , libgpgerror ? pkgs.libgpgerror
      }:

      releaseTools.nixBuild {
        name = "libgcrypt-manual";
        src = tarball;
        buildInputs = (buildInputsFrom pkgs)
          ++ [ libgpgerror ]
          ++ [ pkgs.texinfo pkgs.texLive ];

        buildPhase = "make -C doc html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/libgcrypt/gcrypt.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/libgcrypt/gcrypt.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        inherit meta;
      };
  };

in jobs
