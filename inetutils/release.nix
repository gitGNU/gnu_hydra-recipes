{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [ ncurses ];

  jobs = rec {

    tarball =
      { inetutilsSrc ? { outPath = /data/src/inetutils; }
      , gnulibSrc ? (import ../gnulib.nix) pkgs
      }:

      releaseTools.sourceTarball {
	name = "inetutils-tarball";
	src = inetutilsSrc;

        # Somehow "make dist" alone fails.
        dontBuild = false;
        doCheck = false;

        configureFlags = "--with-ncurses-include-dir=${pkgs.ncurses}/include";

        autoconfPhase = ''
          cp -Rv "${gnulibSrc}" ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --copy
        '';

	buildInputs = (buildInputsFrom pkgs)
          ++ (with pkgs;
              [ autoconf automake111x bison perl git
                texinfo help2man
              ]);
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
          configureFlags = "--with-ncurses-include-dir=${pkgs.ncurses}/include";
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "inetutils-coverage";
	src = tarball;
	buildInputs = buildInputsFrom pkgs;
        configureFlags = "--with-ncurses-include-dir=${pkgs.ncurses}/include";
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
