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
  pkgs = import nixpkgs {};

  meta = {
    homepage = http://www.gnu.org/software/libtasn1/;
    description = "GNU Libtasn1, an ASN.1 library";

    longDescription =
      '' Libtasn1 is the ASN.1 library used by GnuTLS, GNU Shishi and some
         other packages.  The goal of this implementation is to be highly
         portable, and only require an ANSI C89 platform.
      '';

    license = "LGPLv2+";

    maintainers = [ "libtasn1-commit@gnu.org" pkgs.stdenv.lib.maintainers.ludo ];
  };

  inherit (pkgs) releaseTools;

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = {

    tarball =
      { libtasn1Src ? { outPath = ../../libtasn1; }
      }:

      releaseTools.sourceTarball {
	name = "libtasn1-tarball";
	src = libtasn1Src;

        patches = [ ./interpreter-path.patch ];

	preAutoconf =
	  ''sed -i "configure.ac" \
		-e "s/^AC_INIT(\([^,]\+\), \[\([^,]\+\)\]/AC_INIT(\1, [\2-$(git describe || echo git)]/g"
	  '';

	autoconfPhase = "autoreconf -vfi";

        # "make dist" wants `src/asn1Parser' built.
        dontBuild = false;
        configureFlags = [ "--enable-gtk-doc" ];

	buildInputs = with pkgs; [
	  autoconf automake111x libtool help2man
	  git texinfo
          gnome.gtkdoc pkgconfig perl texLive docbook_xsl
          libxml2 /* for the setup hook */
	];

        inherit meta succeedOnFailure keepBuildDirectory;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "libtasn1" ;
          src = tarball;
          inherit meta succeedOnFailure keepBuildDirectory;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "libtasn1-coverage";
	src = tarball;
        inherit meta;
      };

  };

in jobs
