{nixpkgs ? ../../nixpkgs}:
let
  pkgs = import nixpkgs {};

  buildInputs = with pkgs; [
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
        dontBuild = false ;
        buildInputs = [
          automake
          autoconf
          gettext
          flex
          texinfo
        ] ++ buildInputs;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      with import nixpkgs {inherit system;};

      releaseTools.nixBuild rec {
        name = "guile" ;
        src = tarball;
        inherit buildInputs;
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.coverageAnalysis {
        name = "guile-coverage";
        src = tarball;
        inherit buildInputs;
        patches = [
          "${nixpkgs}/pkgs/development/interpreters/guile/disable-gc-sensitive-tests.patch" 
        ];
      };

  };

  
in jobs
