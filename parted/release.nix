{ nixpkgs ? { outPath = ../../nixpkgs; }
, gnulib ? { outPath = ../../gnulib; }
, partedSrc ? { outPath = ../../parted; } }:

let
  pkgs = import nixpkgs {};

  meta = {
    description = "GNU Parted, a tool to create, destroy, resize, check, and copy partitions";

    longDescription = ''
      GNU Parted is an industrial-strength package for creating, destroying,
      resizing, checking and copying partitions, and the file systems on
      them.  This is useful for creating space for new operating systems,
      reorganising disk usage, copying data on hard disks and disk imaging.

      It contains a library, libparted, and a command-line frontend, parted,
      which also serves as a sample implementation and script backend.
    '';

    homepage = http://www.gnu.org/software/parted/;
    license = "GPLv3+";

    maintainers = [
    ];

    # GNU Parted requires libuuid, which is part of util-linux-ng.
    platforms = pkgs.stdenv.lib.platforms.linux;
  };

  jobs = {
    tarball =
      with pkgs;
      releaseTools.sourceTarball {
        name = "parted";
        src = partedSrc;
        buildInputs =
          [ git xz gettext texinfo perl rsync gperf man cvs
            devicemapper libuuid gettext readline pkgconfig # utillinuxng
          ];
        autoconfPhase =
          '' git config submodule.gnulib.url "${gnulib}"
             ./bootstrap --gnulib-srcdir="${gnulib}" --skip-po
          '';
        automake = automake111x;
        inherit meta;
      };

    build =
      { system ? builtins.currentSystem
      , tarball ? jobs.tarball }:

      let pkgs = import nixpkgs { inherit system; };
      in
        with pkgs;
        pkgs.releaseTools.nixBuild {
          name = "parted";
          src = tarball;
          failureHook =
            '' if [ -f tests/test-suite.log ]
               then
                   header 'tests/test-suite.log'
                   echo
                   echo "build failed, dumping test log..."
                   cat tests/test-suite.log
                   stopNest
               fi
            '';
          buildInputs = [devicemapper libuuid gettext readline]; 

          configureFlags = "--with-readline";

          inherit meta;
        };

    coverage =
      { tarball ? jobs.tarball }:

      let pkgs = import nixpkgs {};
      in
        pkgs.releaseTools.coverageAnalysis {
          name = "parted-coverage";
          src = tarball;
        };
  };
in
  jobs
