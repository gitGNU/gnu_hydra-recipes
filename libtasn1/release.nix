{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

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
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "libtasn1-coverage";
	src = tarball;
      };

  };

in jobs
