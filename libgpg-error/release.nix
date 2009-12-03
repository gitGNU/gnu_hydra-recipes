{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [ gettext ];

  jobs = rec {

    tarball =
      { libgpgerrorSrc ? { outPath = /data/src/libgpg-error; }
      }:

      releaseTools.makeSourceTarball {
	name = "libgpgerror-tarball";
	src = libgpgerrorSrc;

        dontBuild = true;

	buildInputs = (buildInputsFrom pkgs) ++ (with pkgs; [
	  autoconf automake111x libtool
	  subversion texinfo
	]);
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "libgpgerror" ;
          src = tarball;
          buildInputs = buildInputsFrom pkgs;
        };

  };

in jobs
