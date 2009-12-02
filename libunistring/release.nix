{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  jobs = rec {

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

	buildInputs = with pkgs; [
          autoconf automake111x libtool texinfo git
          wget perl gperf
	];
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        releaseTools.nixBuild {
          name = "libunistring" ;
          src = tarball;
          buildInputs = [];
          propagatedBuildInputs =
            stdenv.lib.optional (stdenv.isDarwin
                                 || stdenv.system == "i686-cygwin")
              pkgs.libiconv;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
        name = "libunistring-coverage";
        src = tarball;
        buildInputs = [];
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.nixBuild {
        name = "libunistring-manual";
        src = tarball;
        buildInputs = with pkgs; [ perl texinfo texLive ];

        buildPhase = "make -C doc html pdf";
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/libunistring/libunistring_toc.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/libunistring/libunistring.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };

    debian50_i386 = makeDeb_i686 (diskImages: diskImages.debian50i386);
    debian50_x86_64 = makeDeb_x86_64 (diskImages: diskImages.debian50x86_64);
  };

  makeDeb_i686 = makeDeb "i686-linux";
  makeDeb_x86_64 = makeDeb "x86_64-linux";

  makeDeb =
    system: selectDiskImage:
    { tarball ? jobs.tarball {}
    }:

    with import nixpkgs { inherit system; };

    releaseTools.debBuild {
      name = "libunistring-deb";
      src = tarball;
      diskImage = selectDiskImage vmTools.diskImages;
      meta.schedulingPriority = "5";  # low priority
    };

in jobs
