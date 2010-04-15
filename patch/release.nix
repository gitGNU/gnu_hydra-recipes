{ nixpkgs ? { outPath = ../../nixpkgs; }
, gnulib ? { outPath = ../../gnulib; }
, patchSrc ? { outPath = ../../patch; } }:

let
  pkgs = import nixpkgs {};

  jobs = {
    tarball =
      with pkgs;
      releaseTools.sourceTarball {
        name = "patch";
        src = patchSrc;
        buildInputs = [ xz gettext texinfo automake111x ];
        autoconfPhase =
          '' cp -Rv "${gnulib}/"* gnulib/
             chmod -R 755 gnulib

             ./bootstrap --gnulib-srcdir=gnulib --skip-po --copy
          '';
      };

    build =
      { system ? builtins.currentSystem
      , tarball ? jobs.tarball }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "patch";
          src = tarball;
        };

    coverage =
      { tarball ? jobs.tarball }:

      let pkgs = import nixpkgs {};
      in
        pkgs.releaseTools.coverageAnalysis {
          name = "patch-coverage";
          src = tarball;
        };
  };
in
  jobs
