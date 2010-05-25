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
    maintainers =
      [ "Jim Meyering <jim@meyering.net>"
        "Pádraig Brady <P@draigBrady.com>"
        "Ludovic Courtès <ludo@gnu.org>"
      ];
  };

  pkgs = import nixpkgs {};
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  buildInputsFrom = pkgs:
    with pkgs; [ perl gmp ] ++ (stdenv.lib.optional stdenv.isLinux acl);

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
	  bison
	  gettext_0_18
	  git
	  gperf
	  texinfo
	  rsync
	  cvs
	  xz
	] ++ buildInputsFrom pkgs;

        automake = pkgs.automake111x;

	dontBuild = false;

        autoconfPhase = ''
	  sed 's|/usr/bin/perl|${perl}/bin/perl|' -i src/wheel-gen.pl

          git config submodule.gnulib.url "${gnulibSrc}"

          # By default `bootstrap' tries to download `.po' files from the
          # net, which doesn't work in chroots.  Skip that for now and
          # provide an empty `LINGUAS' file.
          touch po/LINGUAS
          ./bootstrap --gnulib-srcdir="${gnulibSrc}" --skip-po
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

    xbuild_gnu =
      # Cross build to GNU.
      { tarball ? jobs.tarball {}
      }:

      let pkgs = import nixpkgs {
            crossSystem = crossSystems.i586_pc_gnu;
          };
      in
      (pkgs.releaseTools.nixBuild {
	name = "coreutils" ;
	src = tarball;
        buildInputs = [ pkgs.gmp ];
	buildNativeInputs = [ pkgs.perl ];
        doCheck = false;
        inherit meta;
      }).hostDrv;

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
