{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [
  ];

  jobs = rec {

    tarball =
      { gnutarSrc ? {outPath = ../../gnutar;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "gnutar-tarball";
        src = gnutarSrc;

        buildInputs = [
          git
          gettext
          cvs
          texinfo
          bison
        ] ++ buildInputsFrom pkgs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "gnutar" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

  };

  
in jobs
