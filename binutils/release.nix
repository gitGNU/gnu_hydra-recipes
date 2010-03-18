{ nixpkgs ? ../../nixpkgs
, binutilsSrc ? { outPath = /data/src/binutils; }
}:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  checkPhase = "make -k check";
  failureHook =
    '' echo "build failed, dumping log files..."
       for log in $(find -name \*.log)
       do
         echo
         echo "--- $log"
         cat "$log"
       done
    '';

  jobs = rec {

    tarball =
      releaseTools.sourceTarball {
        name = "binutils-tarball";
        src = binutilsSrc;
        autoconfPhase = "true";
        buildInputs = with pkgs;
          [ texinfo gettext flex2535 bison ];

        distPhase =
          ''
             make -f src-release "binutils.tar.bz2"
             ensureDir "$out/tarballs"
             mv -v binutils*.bz2 "$out/tarballs"
          '';
      };

    build =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "binutils";
          src = tarball;

          # FIXME: Looks like some GNU ld tests want libdwarf.
          buildInputs = [ pkgs.dejagnu pkgs.zlib ];
          inherit checkPhase failureHook;
        };

    buildGold =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "binutils-gold";
          src = tarball;
          configureFlags = "--enable-gold";
          buildInputs = with pkgs;
            [ dejagnu zlib flex2535 bison ];

          inherit checkPhase failureHook;
        };
  };

in
  jobs
