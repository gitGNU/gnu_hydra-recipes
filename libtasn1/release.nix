{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  deps = pkgs: with pkgs; [ gnome.gtkdoc pkgconfig ];

  jobs = with pkgs; rec {

    tarball =
      { libtasn1Src ? { outPath = ../../libtasn1; }
      }:

      pkgs.releaseTools.makeSourceTarball {
	name = "libtasn1-tarball";
	src = libtasn1Src;

	preAutoconfPhase =
	  ''sed -i "configure.ac" \
		-e "s/^AC_INIT(\([^,]\+\), \[\([^,]\+\)\]/AC_INIT(\1, [\2-$(git describe || echo git)]/g"
	  '';

	autoconfPhase = "make";

        # "make dist" wants `src/asn1Parser' built.
        dontBuild = false;

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
	buildInputs = (deps ((import nixpkgs) { inherit system; }));
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "libtasn1-coverage";
	src = tarball;
	buildInputs = [ gnome.gtkdoc ];
      };

  };

in jobs
