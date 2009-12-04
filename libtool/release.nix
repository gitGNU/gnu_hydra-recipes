{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  jobs = rec {

    tarball =
      { libtoolSrc ? { outPath = /data/src/libtool; }
      , autoconf ? pkgs.autoconf
      , automake ? pkgs.automake111x
      }:

      releaseTools.sourceTarball {
	name = "libtool-tarball";
	src = libtoolSrc;
        bootstrapBuildInputs = [ autoconf automake ];
	buildInputs = with pkgs; [ git texinfo help2man lzma ];

        # help2man wants to run `libtoolize --help'.
        dontBuild = false;

        preConfigurePhases = "preAutoconfPhase autoconfPhase";
        preAutoconfPhase =
          '' echo "checking whether the environment is sane for bootstrap..."
             ( IFS=:
               for i in $ACLOCAL_PATH
               do
                 if find "$i" -name libtool\*m4
                 then
                     echo "found libtool m4 file in \`$i', stopping" >&2
                     exit 1
                 fi
               done ) || exit 1
             echo "environment looks good"
          '';
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , autoconf ? pkgs.autoconf
      , automake ? pkgs.automake
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "libtool";
          src = tarball;
          buildInputs = [ autoconf automake ];

          preCheck =
            # Avoid interference from the ld wrapper.
            '' export NIX_DONT_SET_RPATH=1
               unset NIX_LD_WRAPPER_EXEC_HOOK
               unset NIX_LDFLAGS
               unset NIX_LDFLAGS_BEFORE
               unset NIX_GCC_WRAPPER_FLAGS_SET
            '';
        };

    manual =
      { tarball ? jobs.tarball {}
      , autoconf ? pkgs.autoconf
      , automake ? pkgs.automake
      }:

      releaseTools.nixBuild {
        name = "libtool-manual";
        src = tarball;
        buildInputs =
          [ autoconf automake
            pkgs.texinfo pkgs.texLive
          ];

        buildPhase = "make html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/libtool/libtool.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/libtool/libtool.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };
  };

in jobs
