{ nixpkgs ? ../../nixpkgs }:

let
  meta = {
    description = "GNU Inetutils, a collection of common network programs";

    longDescription = ''
      GNU Inetutils is a collection of common network programs,
      including telnet, FTP, RSH, rlogin and TFTP clients and servers,
      among others.
    '';

    homepage = http://www.gnu.org/software/inetutils/;
    license = "GPLv3+";

    # Email notifications are sent to maintainers.
    maintainers = [ "build-inetutils@gnu.org" ];
  };

  # Work around `AM_SILENT_RULES'.
  preBuild = "export V=99";

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

        inherit preBuild meta;
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
          inherit preBuild meta;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "inetutils-coverage";
	src = tarball;
	buildInputs = buildInputsFrom pkgs;
        configureFlags = "--with-ncurses-include-dir=${pkgs.ncurses}/include";
        inherit preBuild meta;
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
        inherit preBuild meta;
      };
  };

in jobs
