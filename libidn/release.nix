/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010, 2011  Ludovic Courtès <ludo@gnu.org>
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
, libidnSrc ? { outPath = ../../libidn ; rev = 1234; }
}:

let
  pkgs = import nixpkgs {};

  meta = {
    homepage = http://www.gnu.org/software/libidn/;
    description = "GNU Libidn library for internationalized domain names";

    longDescription = ''
      GNU Libidn is a fully documented implementation of the
      Stringprep, Punycode and IDNA specifications.  Libidn's purpose
      is to encode and decode internationalized domain names.  The
      native C, C\# and Java libraries are available under the GNU
      Lesser General Public License version 2.1 or later.

      The library contains a generic Stringprep implementation.
      Profiles for Nameprep, iSCSI, SASL, XMPP and Kerberos V5 are
      included.  Punycode and ASCII Compatible Encoding (ACE) via IDNA
      are supported.  A mechanism to define Top-Level Domain (TLD)
      specific validation tables, and to compare strings against those
      tables, is included.  Default tables for some TLDs are also
      included.
    '';

    license = "LGPLv2+";
    maintainers = [ "libidn-commit@gnu.org" (import nixpkgs {}).stdenv.lib.maintainers.ludo ];
  };

  buildInputsFrom = pkgs: with pkgs;
    [ pkgconfig perl 
      docbook_xsl docbook_xml_dtd_412
      libxml2 /* for the setup hook */
    ]
    # The following packages aren't available on non-GNU platforms.
    ++ stdenv.lib.optionals stdenv.isLinux [ gcj mono gnome.gtkdoc ];

in
  import ../gnu-jobs.nix {
    name = "libidn";
    src  = libidnSrc;
    useLatestGnulib = false;

    inherit nixpkgs meta;

    customEnv = {
        
      tarball = pkgs: {
        dontBuild = false;

        patches = [ ./interpreter-path.patch ./mono-without-binfmt_misc.patch ];

        autoconfPhase = ''
             # If `git describe' doesn't work, keep the default version
             # string since otherwise the `stringprep_check_version' tests
             # fail.
             if git describe > /dev/null
             then
                 version_string="$(git describe | sed -es/libidn-//g | tr - .)"
                 sed -i "configure.ac" \
                     -e "s/^AC_INIT(\([^,]\+\), \[\([^,]\+\)\]/AC_INIT(\1, [$version_string]/g"
             fi

             # Setting this variable allows Mono to run in a chroot without
             # /tmp (otherwise it just abort()s).
             export MONO_SHARED_DIR="$TMPDIR"

             export JAR=gjar
             make

             for i in $(find java -name Makefile.in)
             do
               if grep -q javac "$i"
               then
                   echo "patching \`$i' so that it uses \`gcj' instead of \`javac'..."
                   sed -i "$i" -e's/javac/gcj -C/g'
               fi
             done

             echo "GCJ version:"
             gcj --version
             echo "Mono version:"
             mcs --version
          '';

        configureFlags =
          [ "--enable-gtk-doc" "--enable-java" "--enable-csharp=mono" ];

        buildInputs = (buildInputsFrom pkgs)
          ++ (with pkgs;
               [ autoconf automake111x libtool gettext
             git texinfo gperf gengetopt transfig texLive help2man
                 ghostscript # for `fig2dev'
                 cvs # for `autopoint'
           ]);
      } ;
      
      build = pkgs: {
          preConfigure = "export JAR=gjar MONO_SHARED_DIR=$TMPDIR";
          configureFlags = pkgs.stdenv.lib.optional pkgs.stdenv.isLinux "--enable-java";
          buildInputs = buildInputsFrom pkgs;
      };
      
      coverage = pkgs: {
        preConfigure = "export JAR=gjar MONO_SHARED_DIR=$TMPDIR";
        configureFlags = "--enable-java";
        buildInputs = buildInputsFrom pkgs;
      };
      
    };   
  }
