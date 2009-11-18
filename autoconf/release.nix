{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputs = pkgs: with pkgs; [
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
          echo -n "2.65" > .tarball-version
        '';

        buildInputs = [
          texinfo
          help2man
        ] ++ buildInputs pkgs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild rec {
        name = "autoconf" ;
        src = tarball;
        buildInputs = buildInputs pkgs;
      };

  };

  
in jobs
