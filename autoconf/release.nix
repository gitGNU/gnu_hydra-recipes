{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputs = with pkgs; [
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
        ] ++ buildInputs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      with import nixpkgs {inherit system;};

      releaseTools.nixBuild rec {
        name = "autoconf" ;
        src = tarball;
        inherit buildInputs;
      };

  };

  
in jobs
