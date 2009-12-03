{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  deps = pkgs: with pkgs;
    [ gnome.gtkdoc pkgconfig perl texLive
      help2man docbook_xsl
      libxml2 /* for the setup hook */
    ];

  jobs = rec {

    tarball =
      { libtasn1Src ? { outPath = ../../libtasn1; }
      }:

      releaseTools.makeSourceTarball {
	name = "libtasn1-tarball";
	src = libtasn1Src;

        preConfigurePhases = "preAutoconfPhase autoconfPhase";

	preAutoconfPhase =
	  ''sed -i "configure.ac" \
		-e "s/^AC_INIT(\([^,]\+\), \[\([^,]\+\)\]/AC_INIT(\1, [\2-$(git describe || echo git)]/g"
            sed -i "doc/gdoc" -e"s|/usr/bin/perl|${pkgs.perl}/bin/perl|g"
	  '';

	autoconfPhase = "autoreconf -vfi";

        # "make dist" wants `src/asn1Parser' built.
        dontBuild = false;
        configureFlags = [ "--enable-gtk-doc" ];

	buildInputs = (deps pkgs) ++ (with pkgs; [
	  autoconf automake111x libtool
	  git texinfo
	]);
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
          patchPhase =
            '' sed -i "doc/gdoc" -e"s|#!.*/bin/perl|${pkgs.perl}/bin/perl|g"
            '';

          buildInputs = deps pkgs;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "libtasn1-coverage";
	src = tarball;
	buildInputs = deps (import nixpkgs {});
      };

  };

in jobs
