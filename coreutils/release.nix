{nixpkgs ? ../../nixpkgs}:
let
  meta = {
    homepage = http://www.gnu.org/software/coreutils/;
    description = "The basic file, shell and text manipulation utilities of the GNU operating system";

    longDescription = ''
      The GNU Core Utilities are the basic file, shell and text
      manipulation utilities of the GNU operating system.  These are
      the core utilities which are expected to exist on every
      operating system.
    '';

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [ "Jim Meyering <jim@meyering.net>" ];
  };

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

        inherit meta;
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
        inherit meta;
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
        inherit meta;
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.nixBuild {
        name = "coreutils-manual";
        src = tarball;
        buildInputs = buildInputsFrom pkgs ++ [ pkgs.texinfo pkgs.texLive ];
        doCheck = false;

        buildPhase = "make -C doc html pdf";
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/coreutils/coreutils.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/coreutils/coreutils.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        inherit meta;
      };
  };


in jobs
