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
    description = "GNU MyServer, a powerful and easy to configure web server";

    longDescription = ''
      GNU MyServer is a powerful and easy to configure web server.  Its
      multi-threaded architecture makes it extremely scalable and usable in
      large scale sites as well as in small networks, it has a lot of
      built-in features.  Share your files in minutes!
    '';

    homepage = http://www.gnu.org/software/myserver/;

    license = "GPLv3+";

    # Those who will receive notifications.
    maintainers = [ "myserver-commit@gnu.org" ];
  };

  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs;
    [ libgcrypt libevent libidn gnutls libxml2 zlib texinfo cppunit
      libtasn1  # somehow libbase64 wants libtasn1
    ];

  jobs = rec {

    tarball =
      { myserverSrc ? { outPath = /data/src/myserver; },
        gnulibSrc ? ((import ../gnulib.nix) pkgs)
      }:

      releaseTools.sourceTarball {
	name = "myserver-tarball";
	src = myserverSrc;

        # Somehow "make dist" alone fails.
        dontBuild = false;
        doCheck = false;

        autoconfPhase = ''
          cd myserver

          cp -Rv "${gnulibSrc}" ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --copy --skip-po
        '';

	buildInputs = (buildInputsFrom pkgs)
          ++ (with pkgs;
              [ autoconf automake111x perl git
                gettext_0_17 cvs  # cvs is used by `autopoint'
              ]);

        inherit meta;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "myserver";
          src = tarball;
          buildInputs = buildInputsFrom pkgs;
          inherit meta;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "myserver-coverage";
	src = tarball;
	buildInputs = buildInputsFrom pkgs;
        configureFlags = "--with-ncurses-include-dir=${pkgs.ncurses}/include";
        inherit meta;
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.nixBuild {
        name = "myserver-manual";
        src = tarball;
        buildInputs = (buildInputsFrom pkgs)
          ++ [ pkgs.texinfo pkgs.texLive ];

        buildPhase = "make -C documentation html pdf";
        doCheck = false;
        installPhase =
          '' make -C documentation install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/myserver/myserver.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/myserver/myserver.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        inherit meta;
      };
  };

in jobs
