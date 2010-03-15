{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [ gettext texinfo ];

  # Build out-of-tree; don't produce self rpaths.
  preConfigure =
    ''
       mkdir ../build
       cd ../build

       configureScript="../$sourceRoot/configure"

       # Glibc cannot have itself in its RPATH.
       # See http://sourceware.org/ml/binutils/2009-03/msg00066.html .
       export NIX_NO_SELF_RPATH=1
    '';

  # Return the right configure flags for `pkgs'.
  configureFlagsFor = pkgs:
    [ "--with-headers=${pkgs.linuxHeaders}/include" ]

    # Workaround for this bug:
    #   http://sourceware.org/bugzilla/show_bug.cgi?id=411
    ++ pkgs.stdenv.lib.optional
         (pkgs.stdenv.system == "i686-linux") "CPPFLAGS=-U__i686";

  jobs = rec {

    tarball =
      { glibcSrc ? { outPath = /data/src/glibc; } }:

      releaseTools.sourceTarball {
	name = "glibc-tarball";
	src = glibcSrc;

        patches =
          (map (x: "${nixpkgs}/pkgs/development/libraries/glibc-2.11/${x}")
               [ "locale-override.patch"       # NixOS-specific
                 "rpcgen-path.patch"           # submit upstream?
                 "stack-protector-link.patch"  # submit upstream?
               ])
          ++ [ ./ignore-git-diff.patch
               ./add-local-changes-to-tarball.patch
             ];


        # The repository contains Autoconf-generated files & co.
        autoconfPhase = "true";
        bootstrapBuildInputs = [];

        # Remove absolute paths from `configure' & co.; build out-of-tree.
        preConfigure =
          ''
             set -x
             for i in configure io/ftwtest-sh; do
                 sed -i "$i" -e "s^/bin/pwd^pwd^g"
             done

             ${preConfigure}
          '';

        buildInputs = (buildInputsFrom pkgs) ++ [ pkgs.git pkgs.xz ];

        # Jump back to where the tarballs are and copy them from there.
        dontCopyDist = true;
        postDist =
          ''
             cd "../$sourceRoot"
             ensureDir "$out/tarballs"
             mv -v glibc-*.tar.{bz2,gz,xz} "$out/tarballs"
          '';
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "glibc";
          src = tarball;
          configureFlags = configureFlagsFor pkgs;
          buildInputs = buildInputsFrom pkgs;
          inherit preConfigure;
        };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      let pkgs = import nixpkgs { system = "x86_64-linux"; };
      in
        releaseTools.coverageAnalysis {
          name = "glibc-coverage";
          src = tarball;
          configureFlags = configureFlagsFor pkgs;
          buildInputs = buildInputsFrom pkgs;
          inherit preConfigure;
        };

  };

in jobs
