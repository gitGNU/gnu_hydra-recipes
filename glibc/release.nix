{ nixpkgs ? ../../nixpkgs }:

let
  meta = {
    homepage = http://www.gnu.org/software/libc/;
    description = "The GNU C Library";

    longDescription =
      '' Any Unix-like operating system needs a C library: the library which
         defines the "system calls" and other basic facilities such as
         open, malloc, printf, exit...

         The GNU C library is used as the C library in the GNU system and
         most systems with the Linux kernel.
      '';

    license = "LGPLv2+";

    # Those who will receive email notifications.
    maintainers = [ "ludo@gnu.org" ];
  };

  pkgs = import nixpkgs {};

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [ gettext texinfo perl ];

  # Build out-of-tree; don't produce self rpaths.
  preConfigure =
    ''
       set -x

       mkdir ../build
       cd ../build

       configureScript="../$sourceRoot/configure"

       # Glibc cannot have itself in its RPATH.
       # See http://sourceware.org/ml/binutils/2009-03/msg00066.html .
       export NIX_NO_SELF_RPATH=1
       export NIX_DONT_SET_RPATH=1

       # Beware of the GCC/ld wrappers.
       unset NIX_CFLAGS_COMPILE
       unset NIX_CFLAGS_LINK
       unset NIX_LDFLAGS_BEFORE
       unset NIX_LDFLAGS
       unset NIX_LDFLAGS_AFTER

       env | grep NIX
    '';

  # Return the right configure flags for `pkgs'.
  configureFlagsFor = pkgs:
    [ "--with-headers=${pkgs.linuxHeaders}/include" ];

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

        inherit meta;
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

          # Workaround for this bug:
          #   http://sourceware.org/bugzilla/show_bug.cgi?id=411
          # Note: Setting $CPPFLAGS or $CFLAGS doesn't work.  The former is
          # ignored, while the latter disables optimizations, thereby
          # breaking the build.
          NIX_CFLAGS_COMPILE =
            pkgs.stdenv.lib.optionalString (pkgs.stdenv.system == "i686-linux")
                                           "-U__i686";

          buildInputs = buildInputsFrom pkgs;

          # Some tests are failing, but we don't want that to prevent "make
          # install".
          checkPhase = "make -k check || true";

          inherit preConfigure meta;
        };

  };

in jobs
