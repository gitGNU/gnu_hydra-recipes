{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [ perl help2man ];

  jobs = rec {

    tarball =
      { automakeSrc ? { outPath = ../../automake; }
      , autoconf ? pkgs.autoconf
      }:

      releaseTools.makeSourceTarball {
        name = "automake-tarball";
        src = automakeSrc;
        dontBuild = false;

        /* XXX: Automake says "version is incorrect" if you try to check its
           version number as is done below.  That's unfortunate.

        preConfigurePhases = "preAutoconfPhase autoconfPhase";
        preAutoconfPhase =
          ''sed -i "configure.ac" \
                -e "s/^AC_INIT(\([^,]\+\), \[\([^,]\+\)\]/AC_INIT(\1, [\2-$(git describe || echo git)]/g"
          '';
         */

        buildInputs = (with pkgs; [ texinfo git ])
          ++ [ autoconf ] ++ (buildInputsFrom pkgs);
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , autoconf ? pkgs.autoconf
      }:

      let pkgs = import nixpkgs {inherit system;};
      in
        releaseTools.nixBuild {
          name = "automake" ;
          src = tarball;
          buildInputs = [ autoconf ] ++ (buildInputsFrom pkgs);

          # Disable indented log output from Make, otherwise "make.test" will
          # fail.
          preCheck = "unset NIX_INDENT_MAKE";
        };
  };

in jobs
