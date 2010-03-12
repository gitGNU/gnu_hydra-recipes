{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [ readline bison ];

  jobs = rec {

    tarball =
      { bashSrc }:

      releaseTools.sourceTarball {
	name = "bash-tarball";
	src = bashSrc;

        # The generated files are checked in.
        autoconfPhase = "true";

        distPhase =
          # Bash doesn't use Automake.  The makefile says one should use the
          # `support/mkdist' script but that script doesn't exist.
          ''
             version="4.1-$(cat .git/refs/heads/master | cut -c 1-8)"

             mkdir "bash-$version"
             for dir in `cat MANIFEST |grep -v '^#' | grep -v '[[:blank:]]\+f' | sed -es'/[[:blank:]]\+d.*//g'`
             do
               mkdir -v "bash-$version/$dir"
             done
             for file in `cat MANIFEST |grep -v '^#' | grep -v '[[:blank:]]\+d' | sed -es'/[[:blank:]]\+f.*//g'`
             do
               cp -pv "$file" "bash-$version/$file"
             done

             mkdir -p "$out/tarballs"
             GZIP=--best tar czf "$out/tarballs/bash-$version.tar.gz" "bash-$version"
          '';

        doCheck = false;
	buildInputs = (buildInputsFrom pkgs);
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "bash";
          src = tarball;
          buildInputs = buildInputsFrom pkgs;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "bash-coverage";
	src = tarball;
	buildInputs = buildInputsFrom pkgs;
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.nixBuild {
        name = "bash-manual";
        src = tarball;
        buildInputs = (buildInputsFrom pkgs)
          ++ [ pkgs.texinfo pkgs.texLive ];

        buildPhase = "make -C doc html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install_everything
             cp -v doc/bashref.{pdf,html} "$out/share/doc/bash"

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/bash/bashref.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/bash/bashref.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };
  };

in jobs
