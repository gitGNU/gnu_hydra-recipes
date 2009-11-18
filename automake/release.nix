{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputs = with pkgs; [
    perl
    help2man
    autoconf
  ];

  jobs = rec {

    tarball =
      { automakeSrc ? {outPath = ../../automake;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "automake-tarball";
        src = automakeSrc;
        dontBuild = false;

        buildInputs = [
          texinfo
        ] ++ buildInputs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      with import nixpkgs {inherit system;};

      releaseTools.nixBuild rec {
        name = "automake" ;
        src = tarball;
        inherit buildInputs;
      };

  };

  
in jobs
