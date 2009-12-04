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

        bootstrapBuildInputs = [ autoconf ];
        buildInputs = (with pkgs; [ texinfo git ]) ++ (buildInputsFrom pkgs);
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , autoconf ? pkgs.autoconf
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "automake" ;
          src = tarball;
          bootstrapBuildInputs = [ autoconf ];
          buildInputs = buildInputsFrom pkgs;

          # Disable indented log output from Make, otherwise "make.test" will
          # fail.  Ask for verbose test suite output.
          preCheck = "unset NIX_INDENT_MAKE ; export VERBOSE=yes";
        };
  };

in jobs
