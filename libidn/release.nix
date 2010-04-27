{ nixpkgs ? ../../nixpkgs }:

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
    maintainers = [ "libidn-commit@gnu.org" pkgs.stdenv.lib.maintainers.ludo ];
  };

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs;
    [ pkgconfig perl texLive
      help2man docbook_xsl docbook_xml_dtd_412
      libxml2 /* for the setup hook */
    ]

    # The following packages aren't available on non-GNU platforms.
    ++ stdenv.lib.optionals stdenv.isLinux [ gcj mono gnome.gtkdoc ];

  jobs = {

    tarball =
      { libidnSrc }:

      releaseTools.sourceTarball {
	name = "libidn-tarball";
	src = libidnSrc;

        # `help2man' wants to run the programs.
        dontBuild = false;

        patches = [ ./interpreter-path.patch ./mono-without-binfmt_misc.patch ];

	autoconfPhase =
	  '' # If `git describe' doesn't work, keep the default version
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
	         git texinfo gperf gengetopt transfig
                 ghostscript # for `fig2dev'
                 cvs # for `autopoint'
	       ]);

        inherit meta;
      };

    build =
      { tarball, system }:

      let pkgs = import nixpkgs { inherit system; };
      in
        with pkgs;
        releaseTools.nixBuild {
          name = "libidn" ;
          src = tarball;
          preConfigure = "export JAR=gjar MONO_SHARED_DIR=$TMPDIR";
          configureFlags = stdenv.lib.optional stdenv.isLinux "--enable-java";
          buildInputs = buildInputsFrom pkgs;
          inherit meta;
        };

    coverage =
      { tarball }:

      releaseTools.coverageAnalysis {
	name = "libidn-coverage";
	src = tarball;
        preConfigure = "export JAR=gjar MONO_SHARED_DIR=$TMPDIR";
        configureFlags = "--enable-java";
	buildInputs = buildInputsFrom (import nixpkgs {});
        inherit meta;
      };

  };

in jobs
