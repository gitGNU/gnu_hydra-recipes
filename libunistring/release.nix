{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  jobs = with pkgs; rec {

    tarball =
      { libunistringSrc ? { outPath = ../../libunistring; }
      , gnulib ? { outPath = ../../gnulib; }
      }:

      pkgs.releaseTools.makeSourceTarball {
	name = "libunistring-tarball";
	src = libunistringSrc;

	autoconfPhase = ''
	  GNULIB_TOOL="${gnulib}/gnulib-tool" ./autogen.sh
	'';

	buildInputs = [
          autoconf
          automake
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
	name = "libunistring" ;
	src = tarball;
	buildInputs = [];
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.coverageAnalysis {
        name = "libunistring-coverage";
        src = tarball;
        buildInputs = [];
      };

  };

in jobs
