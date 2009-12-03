{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [];

  jobs = rec {

    tarball =
      { inetutilsSrc ? { outPath = /data/src/inetutils; }
      , gnulibSrc ? (import ../gnulib.nix) pkgs
      }:

      releaseTools.makeSourceTarball {
	name = "inetutils-tarball";
	src = inetutilsSrc;

        autoconfPhase = ''
          cp -Rv "${gnulibSrc}" ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --copy
        '';

	buildInputs = (buildInputsFrom pkgs)
          ++ (with pkgs; [ autoconf automake111x bison git texinfo ]);
      };

    # XXX: Compile `--with-shishi'.
    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "inetutils";
          src = tarball;
          buildInputs = buildInputsFrom pkgs;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "inetutils-coverage";
	src = tarball;
	buildInputs = buildInputsFrom (import nixpkgs {});
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.nixBuild {
        name = "inetutils-manual";
        src = tarball;
        buildInputs = (buildInputsFrom pkgs)
          ++ [ pkgs.texinfo pkgs.texLive ];

        buildPhase = "make -C doc html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/inetutils/inetutils.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/inetutils/inetutils.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };
  };

in jobs
