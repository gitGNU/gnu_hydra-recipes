{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  deps = pkgs: with pkgs;
    [ gnome.gtkdoc pkgconfig perl texLive
      help2man docbook_xsl
      libxml2 /* for the setup hook */
    ];

  jobs = with pkgs; rec {

    tarball =
      { libtasn1Src ? { outPath = ../../libtasn1; }
      }:

      pkgs.releaseTools.makeSourceTarball {
	name = "libtasn1-tarball";
	src = libtasn1Src;

        preConfigurePhases = "preAutoconfPhase autoconfPhase";

	preAutoconfPhase =
	  ''sed -i "configure.ac" \
		-e "s/^AC_INIT(\([^,]\+\), \[\([^,]\+\)\]/AC_INIT(\1, [\2-$(git describe || echo git)]/g"
            sed -i "doc/gdoc" -e"s|/usr/bin/perl|${perl}/bin/perl|g"
	  '';

	autoconfPhase = "autoreconf -vfi";

        # "make dist" wants `src/asn1Parser' built.
        dontBuild = false;
        configureFlags = [ "--enable-gtk-doc" ];

	buildInputs = (deps pkgs) ++ [
	  autoconf
	  automake111x
	  git
	  libtool
	  texinfo
	];
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      releaseTools.nixBuild {
	name = "libtasn1" ;
	src = tarball;
        patchPhase =
          '' sed -i "doc/gdoc" -e"s|#!.*/bin/perl|${perl}/bin/perl|g"
          '';

	buildInputs = deps ((import nixpkgs) { inherit system; });
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "libtasn1-coverage";
	src = tarball;
	buildInputs = deps ((import nixpkgs) {});
      };

  };

in jobs
