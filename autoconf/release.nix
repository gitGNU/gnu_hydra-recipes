{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [ perl m4 ];

  jobs = rec {

    tarball =
      { autoconfSrc ? {outPath = ../../autoconf;}
      }:

      with pkgs;

      pkgs.releaseTools.sourceTarball {
        name = "autoconf-tarball";
        src = autoconfSrc;
        preConfigurePhases = "preAutoconfPhase autoconfPhase";
        preAutoconfPhase = ''
          echo -n "$(git describe)" > .tarball-version
        '';

        # Autoconf needs a version of itself to bootstrap.
        bootstrapBuildInputs = [ autoconf ];
        buildInputs = [
          texinfo
          help2man
          git
        ] ++ buildInputsFrom pkgs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "autoconf" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      pkgs.releaseTools.nixBuild {
        name = "autoconf-manual";
        src = tarball;
        buildInputs = [ pkgs.texinfo pkgs.texLive ] ++ (buildInputsFrom pkgs);

        buildPhase = "make html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/autoconf/autoconf.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/autoconf/autoconf.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };
  };

in jobs
