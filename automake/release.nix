{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [
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
        ] ++ buildInputsFrom pkgs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild {
        name = "automake" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;

        # Disable indented log output from Make, otherwise "make.test" will
        # fail.
        preCheck = "unset NIX_INDENT_MAKE";
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.coverageAnalysis {
        name = "automake-coverage";
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

  };

  
in jobs
