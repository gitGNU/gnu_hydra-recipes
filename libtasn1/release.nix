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

        inherit meta;
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
          inherit meta;
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
