{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs;
    [ pkgconfig perl texLive
      help2man docbook_xsl docbook_xml_dtd_412
      libxml2 /* for the setup hook */
    ]

    # The following packages aren't available on non-GNU platforms.
    ++ stdenv.lib.optionals stdenv.isLinux [ gcj mono gnome.gtkdoc ];

  jobs = rec {

    tarball =
      { libidnSrc }:

      releaseTools.sourceTarball {
	name = "libidn-tarball";
	src = libidnSrc;

        # `help2man' wants to run the programs.
        dontBuild = false;

        patches = [ ./mono-without-binfmt_misc.patch ];

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

             sed -i "doc/gdoc" -e"s|/usr/bin/perl|${pkgs.perl}/bin/perl|g"

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
      };

    build =
      { tarball, system }:

      let pkgs = import nixpkgs { inherit system; };
      in
        with pkgs;
        releaseTools.nixBuild {
          name = "libidn" ;
          src = tarball;
          patchPhase =
            '' sed -i "doc/gdoc" -e"s|#!.*/bin/perl|${perl}/bin/perl|g"
            '';
          preConfigure = "export JAR=gjar MONO_SHARED_DIR=$TMPDIR";
          configureFlags = stdenv.lib.optional stdenv.isLinux "--enable-java";
          buildInputs = buildInputsFrom pkgs;
        };

    coverage =
      { tarball }:

      releaseTools.coverageAnalysis {
	name = "libidn-coverage";
	src = tarball;
        patchPhase =
          '' sed -i "doc/gdoc" -e"s|#!.*/bin/perl|${pkgs.perl}/bin/perl|g"
          '';
        preConfigure = "export JAR=gjar MONO_SHARED_DIR=$TMPDIR";
        configureFlags = "--enable-java";
	buildInputs = buildInputsFrom (import nixpkgs {});
      };

  };

in jobs
