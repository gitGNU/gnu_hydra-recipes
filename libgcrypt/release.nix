{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [];

  jobs = rec {

    tarball =
      { libgcryptSrc ? { outPath = /data/src/libgcrypt; }
      , libgpgerror ? pkgs.libgpgerror
      }:

      releaseTools.makeSourceTarball {
	name = "libgcrypt-tarball";
	src = libgcryptSrc;

	buildInputs = (buildInputsFrom pkgs)
          ++ [ libgpgerror ]
          ++ (with pkgs; [
	       autoconf automake111x
               libtool_1_5 # the repo contains Libtool 1.5's `ltmain.sh', etc.
	       subversion texinfo transfig ghostscript
	      ]);
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , libgpgerror ? pkgs.libgpgerror
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "libgcrypt";
          src = tarball;
          buildInputs = (buildInputsFrom pkgs) ++ [ libgpgerror ];
        };

    coverage =
      { tarball ? jobs.tarball {}
      , libgpgerror ? pkgs.libgpgerror
      }:

      releaseTools.coverageAnalysis {
	name = "libgcrypt-coverage";
	src = tarball;
	buildInputs = (buildInputsFrom (import nixpkgs {})) ++ [ libgpgerror ];
      };

    manual =
      { tarball ? jobs.tarball {}
      , libgpgerror ? pkgs.libgpgerror
      }:

      releaseTools.nixBuild {
        name = "libgcrypt-manual";
        src = tarball;
        buildInputs = (buildInputsFrom pkgs)
          ++ [ libgpgerror ]
          ++ [ pkgs.texinfo pkgs.texLive ];

        buildPhase = "make -C doc html pdf";
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/libgcrypt/gcrypt.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/libgcrypt/gcrypt.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };
  };

in jobs
