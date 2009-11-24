{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

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

	buildInputs = [
	  autoconf
	  automake111x
	  git
	  gnome.gtkdoc
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
	buildInputs = [ gnome.gtkdoc ];
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
