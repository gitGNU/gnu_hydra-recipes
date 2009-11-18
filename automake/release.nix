{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputs = pkgs: with pkgs; [
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

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild rec {
        name = "automake" ;
        src = tarball;
        buildInputs = buildInputs pkgs;
      };

  };

  
in jobs
