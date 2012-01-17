/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010, 2011, 2012  Ludovic Courtès <ludo@gnu.org>

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

{ nixpkgs ? <nixpkgs> }:

let
  meta = {
    description = "The GNU Transport Layer Security Library";

    longDescription = ''
       GnuTLS is a project that aims to develop a library which
       provides a secure layer, over a reliable transport
       layer. Currently the GnuTLS library implements the proposed
       standards by the IETF's TLS working group.

       Quoting from the TLS protocol specification:

       "The TLS protocol provides communications privacy over the
       Internet. The protocol allows client/server applications to
       communicate in a way that is designed to prevent eavesdropping,
       tampering, or message forgery."
    '';

    homepage = http://www.gnu.org/software/gnutls/;
    license = "LGPLv2.1+";

    # Where notification emails go.
    maintainers = [ "gnutls-commit@gnu.org" "ludo@gnu.org" ];
  };

  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs;
    [ xz zlib lzo gettext_0_18 pkgconfig perl nettle]
    ++ stdenv.lib.optional (stdenv.system == "x86_64-linux") valgrind
    ++ stdenv.lib.optional (stdenv.isDarwin || stdenv.isBSD) libiconv;

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = rec {

    tarball =
      { gnutlsSrc ? { outPath = <gnutls>; }
      , libtasn1 ? pkgs.libtasn1
      , libgcrypt ? pkgs.libgcrypt
      }:

      let
        git2cl = pkgs.stdenv.fetchurl {
                   # XXX: Unversioned URL!
                   url = "http://josefsson.org/git2cl/git2cl";
                   sha256 = "1b9anjnycaw9vqwf8hx4p9xgngpbm7anx4i2w7a08pm09p72p08k";
                 };
      in
      releaseTools.sourceTarball {
	name = "gnutls-tarball";
	src = gnutlsSrc;

        # "make dist" alone won't work (`doc/error_codes.texi' depends on
        # `doc/errcodes', which depends on `libgnutls.la'), so run "make"
        # before.
        dontBuild = false;

        patchPhase =
          # Copy `git2cl' and add it to $PATH.
          # Remove occurrences of /usr/bin/perl and /bin/bash.
          '' mkdir "$TMPDIR/bin"
             cp -v "${git2cl}" "$TMPDIR/bin"
             chmod +x "$TMPDIR/bin/git2cl"
             export PATH="$TMPDIR/bin:$PATH"

             for i in                           \
                tests/nist-pkits/build-chain    \
                doc/scripts/sort2.pl            \
                doc/scripts/gdoc                \
                doc/doxygen/Doxyfile.orig       \
                doc/doxygen/Doxyfile.in         \
                "$TMPDIR/bin/git2cl"
             do
               echo "patching \`/usr/bin/perl' in \`$i'..."
               sed -i "$i" -e's|/usr/bin/perl|${pkgs.perl}/bin/perl|g'
             done

             for i in "tests/"*"/"*
             do
               if grep -q /bin/bash "$i"
               then
                 echo "patching \`/bin/bash' in \`$i'..."
                 sed -i "$i" -e's|/bin/bash|/bin/sh|g'
               fi
             done
          '';

        doCheck = false;

        autoconfPhase = "make autoreconf";
        configureFlags =
          "--with-lzo --with-libtasn1-prefix=${libtasn1} --enable-guile"
          + " --enable-gtk-doc";
	buildInputs = (buildInputsFrom pkgs)
          ++ [ libtasn1 libgcrypt ]
          ++ (with pkgs;
              [ autoconf automake111x git
                texinfo help2man
                cvs # for `autopoint'
                gnome.gtkdoc docbook_xsl
                libxml2 # for its setup-hook
                texinfo texLive
                guile
              ]);

        inherit meta succeedOnFailure keepBuildDirectory;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , libtasn1 ? pkgs.libtasn1
      , libgcrypt ? pkgs.libgcrypt
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "gnutls";
          src = tarball;
          configureFlags =
            "--with-lzo --with-libtasn1-prefix=${libtasn1} --enable-guile";
          buildInputs = (buildInputsFrom pkgs)
             ++ [ pkgs.guile libtasn1 libgcrypt ];
          inherit meta succeedOnFailure keepBuildDirectory;
        };

    build_guile_1_8 =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , libtasn1 ? pkgs.libtasn1
      , libgcrypt ? pkgs.libgcrypt
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "gnutls-with-guile-1.8";
          src = tarball;
          configureFlags =
            "--with-lzo --with-libtasn1-prefix=${libtasn1} --enable-guile";
          buildInputs = (buildInputsFrom pkgs)
            ++ [ pkgs.guile_1_8 libtasn1 libgcrypt ];
          inherit succeedOnFailure keepBuildDirectory;
          meta = meta // {
            description = meta.description + " (with Guile 1.8.x)";
            schedulingPriority = 20;
          };
        };

    coverage =
      { tarball ? jobs.tarball {}
      , libtasn1 ? pkgs.libtasn1
      , libgcrypt ? pkgs.libgcrypt
      }:

      releaseTools.coverageAnalysis {
	name = "gnutls-coverage";
	src = tarball;
        configureFlags =
          "--with-lzo --with-libtasn1-prefix=${libtasn1} --enable-guile";
        buildInputs = (buildInputsFrom pkgs)
          ++ [ pkgs.guile libtasn1 libgcrypt ];
        # No mail notifications.
        meta.schedulingPriority = 20;
      };

    manual =
      { tarball ? jobs.tarball {}
      , libtasn1 ? pkgs.libtasn1
      , libgcrypt ? pkgs.libgcrypt
      }:

      releaseTools.nixBuild {
        name = "gnutls-manual";
        src = tarball;
        configureFlags =
          "--with-lzo --with-libtasn1-prefix=${libtasn1} --enable-guile";
        buildInputs = (buildInputsFrom pkgs)
          ++ [ libtasn1 libgcrypt ]
          ++ (with pkgs; [ guile texinfo texLive ]);

        buildPhase = "make && make -C doc html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/gnutls/gnutls.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/gnutls/gnutls.pdf" >> "$out/nix-support/hydra-build-products"
             echo "doc manual $out/share/doc/gnutls/gnutls-guile.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/gnutls/gnutls-guile.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        inherit meta;
      };
  };

in jobs
