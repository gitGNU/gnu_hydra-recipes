/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009, 2010  Ludovic Courtès <ludo@gnu.org>
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

{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  meta = {
    homepage = http://www.gnu.org/software/libunistring/;

    description = "GNU Libunistring, a Unicode string library";

    longDescription = ''
      This library provides functions for manipulating Unicode strings
      and for manipulating C strings according to the Unicode
      standard.

      GNU libunistring is for you if your application involves
      non-trivial text processing, such as upper/lower case
      conversions, line breaking, operations on words, or more
      advanced analysis of text.  Text provided by the user can, in
      general, contain characters of all kinds of scripts.  The text
      processing functions provided by this library handle all scripts
      and all languages.

      libunistring is for you if your application already uses the ISO
      C / POSIX <ctype.h>, <wctype.h> functions and the text it
      operates on is provided by the user and can be in any language.

      libunistring is also for you if your application uses Unicode
      strings as internal in-memory representation.
    '';

    license = "LGPLv3+";

    maintainers = [ pkgs.stdenv.lib.maintainers.ludo ];
  };

  inherit (pkgs) releaseTools;

  jobs = rec {

    tarball =
      { libunistringSrc ? { outPath = ../../libunistring; }
      , gnulibSrc ? { outPath = ../../gnulib; }
      }:

      releaseTools.makeSourceTarball {
	name = "libunistring-tarball";
	src = libunistringSrc;

        patches = [ ./tar-should-not-expect-a-root-user.patch ];

	autoconfPhase = ''
	  export GNULIB_TOOL="../gnulib/gnulib-tool"
          cp -Rv "${gnulibSrc}" ../gnulib
          chmod -R 755 ../gnulib

          # Remove Libtool-provided files to avoid any conflicts with the
          # version we're using here.
          rm -fv m4/libtool* m4/lt* libtool build-aux/lt*
          libtoolize --install --force

          ./autogen.sh
	'';

	buildInputs = with pkgs; [
          autoconf automake111x libtool texinfo git
          wget perl gperf
	];

        inherit meta;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "libunistring" ;
          src = tarball;
          buildInputs = [];
          propagatedBuildInputs = with pkgs;
            stdenv.lib.optional (stdenv.isDarwin
                                 || stdenv.system == "i686-cygwin")
              libiconv;
          inherit meta;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
        name = "libunistring-coverage";
        src = tarball;
        buildInputs = [];
        inherit meta;
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.nixBuild {
        name = "libunistring-manual";
        src = tarball;
        buildInputs = with pkgs; [ perl texinfo texLive ];

        buildPhase = "make -C doc html pdf";
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/libunistring libunistring_toc.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/libunistring/libunistring.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        inherit meta;
      };

    debian50_i386 = makeDeb_i686 (diskImages: diskImages.debian50i386);
    debian50_x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian50x86_64);
  };

  makeDeb_i686 = makeDeb "i686-linux";
  makeDeb_x86_64 = makeDeb "x86_64-linux";

  makeDeb =
    system: selectDiskImage:
    { tarball ? jobs.tarball {}
    }:

    with import nixpkgs { inherit system; };

    releaseTools.debBuild {
      name = "libunistring-deb";
      src = tarball;
      diskImage = selectDiskImage vmTools.diskImages;
      meta.schedulingPriority = "5";  # low priority
    };

in jobs
