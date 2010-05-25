{ nixpkgs ? { outPath = ../../nixpkgs; }
, libredwgSrc ? { outPath = ../../libredwg; } }:

let
  pkgs = import nixpkgs {};

  meta = {
    description = "GNU LibreDWG, a free C library to handle DWG files.";

    longDescription =
      '' GNU LibreDWG is a free C library to handle DWG files. It aims to be a free 
         replacement for the OpenDWG libraries. DWG is the native file format of AutoCAD. 
      '';

    homepage = http://www.gnu.org/software/libredwg/;

    license = "GPLv3+";

    maintainers =
     [ 
     ];
  };

  jobs = {
    tarball =
      with pkgs;
      releaseTools.sourceTarball {
        name = "libredwg";
        src = libredwgSrc;
        buildInputs =
          [ gettext texinfo automake111x
          ];
        inherit meta;
      };

    build =
      { system ? builtins.currentSystem
      , tarball ? jobs.tarball }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "libredwg";
          src = tarball;
          inherit meta;
        };

    coverage =
      { tarball ? jobs.tarball }:

      let pkgs = import nixpkgs {};
      in
        pkgs.releaseTools.coverageAnalysis {
          name = "libredwg-coverage";
          src = tarball;
        };
  };
in
  jobs
