{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [
    perl 
    m4
  ];

  jobs = rec {

    tarball =
      { autoconfSrc ? {outPath = ../../autoconf;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "autoconf-tarball";
        src = autoconfSrc;
        preConfigurePhases = "preAutoconfPhase autoconfPhase"; 
        preAutoconfPhase = ''
          echo -n "$(git describe)" > .tarball-version
        '';

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

  };

in jobs
