{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [ perl ];

  jobs = rec {

    tarball =
      { coreutilsSrc ? {outPath = ../../coreutils;}
      , gnulibSrc ? (import ../gnulib.nix) pkgs
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
	name = "coreutils-tarball";
	src = coreutilsSrc;

	buildInputs = [
	  automake111x
	  bison
	  gettext
	  git
	  gperf
	  texinfo
	  rsync
	  cvs
	  xz
	] ++ buildInputsFrom pkgs;

	dontBuild = false;

        autoconfPhase = ''
          cp -Rv "${gnulibSrc}" ../gnulib
          chmod -R 755 ../gnulib

	  sed 's|/usr/bin/perl|${perl}/bin/perl|' -i src/wheel-gen.pl

          ./bootstrap --gnulib-srcdir=../gnulib --copy
        '';

      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in
      pkgs.releaseTools.nixBuild {
	name = "coreutils" ;
	src = tarball;
	buildInputs = buildInputsFrom pkgs ++ [ pkgs.texinfo pkgs.texLive ];
        installPhase =
          '' make install

             echo "installing the HTML and PDF manual..."
             make install-html install-pdf -C doc
             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/coreutils/coreutils.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/coreutils/coreutils.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.coverageAnalysis {
	name = "coreutils-coverage";
	src = tarball;
	buildInputs = buildInputsFrom pkgs;
        postCheck =
          # Remove the file that confuses lcov.
          '' rm -fv 'src/<built-in>.'*
             rm -fv src/getlimits.gc*
          '';
      };

  };


in jobs
