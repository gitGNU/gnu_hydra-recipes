{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  jobs = rec {

    tarball =
      { gslSrc ? { outPath = /data/src/gsl; }
      }:

      releaseTools.sourceTarball {
	name = "gsl-tarball";
	src = gslSrc;
        doCheck = false;
        preAutoconf =
          '' version_string="$((git describe || echo git) | sed -es/release-//g | tr - .)"
             sed -i configure.ac -"es/^AC_INIT.*$/AC_INIT([gsl], [$version_string])/"
             : > BUGS
          '';
	buildInputs =
          with pkgs;
            [ autoconf automake111x git texinfo];
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "gsl";
          src = tarball;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "gsl-coverage";
	src = tarball;
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.nixBuild {
        name = "gsl-manual";
        src = tarball;
        buildInputs = [ pkgs.texinfo pkgs.texLive pkgs.ghostscript ];

        buildPhase = "make -C doc html ps && ( cd doc ; ps2pdf gsl-ref.ps )";
        doCheck = false;
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/gsl/gsl-ref.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/gsl/gsl-ref.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };
  };

in jobs
