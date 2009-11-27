{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  jobs = with pkgs; rec {

    tarball =
      { libunistringSrc ? { outPath = ../../libunistring; }
      , gnulibSrc ? { outPath = ../../gnulib; }
      }:

      pkgs.releaseTools.makeSourceTarball {
	name = "libunistring-tarball";
	src = libunistringSrc;

	autoconfPhase = ''
	  export GNULIB_TOOL="../gnulib/gnulib-tool"
          cp -Rv "${gnulibSrc}" ../gnulib
          chmod -R 755 ../gnulib
          ./autogen.sh
	'';

	buildInputs = [
          autoconf
          automake111x
          git
          libtool
          texinfo
          wget
          perl
          gperf
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
