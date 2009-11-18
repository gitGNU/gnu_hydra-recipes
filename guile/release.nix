{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [
    readline 
    libtool 
    gmp 
    gawk 
    makeWrapper
    libunistring 
    pkgconfig 
    boehmgc
  ];

  jobs = rec {

    tarball =
      { guileSrc ? {outPath = ../../guile;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "guile-tarball";
        src = guileSrc;
        buildInputs = [
          automake
          autoconf
          flex
          gettext
          gnum4  # this should be a propagated build input of Autotools
          texinfo
        ] ++ buildInputsFrom pkgs;

        preConfigurePhases = "preAutoconfPhase autoconfPhase";

        preAutoconfPhase =
          # Add a Git descriptor in the version number, assuming Hydra
          # created a `.git-version' file upon checkout.  Tell Automake not
          # to check whether `NEWS' is up to date wrt. that version number.
          '' sed -i "GUILE-VERSION" \
                 -es"/^\(GUILE_VERSION=.*\)/\1-$(cat .git-version || echo git)/g"
             sed -i "configure.ac" -es"/check-news//g"
          '';
        patches = [ ./disable-version-test.patch ];
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild rec {
        name = "guile" ;
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.coverageAnalysis {
        name = "guile-coverage";
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
        patches = [
          "${nixpkgs}/pkgs/development/interpreters/guile/disable-gc-sensitive-tests.patch" 
        ];
      };

  };

  
in jobs
