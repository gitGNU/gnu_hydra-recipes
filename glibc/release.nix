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

  # Cross-compilation jobs.
  makeCrossBuild = crossSystem:
    { tarball ? jobs.tarball {} }:

    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system crossSystem; };
    in
      (pkgs.releaseTools.nixBuild {
        name = "glibc-${crossSystem.config}";
        src = tarball;
        configureFlags = configureFlagsFor pkgs
          ++ [ "--host=${crossSystem.config}"
               "--enable-kernel=2.6.0"
               "--with-__thread"
               (if crossSystem.withTLS
                then "--with-tls"
                else "--without-tls")
               (if crossSystem.float == "soft"
                then "--without-fp"
                else "--with-fp")
             ];

        buildNativeInputs = buildInputsFrom pkgs;
        doCheck = false;
        inherit preConfigure meta;
      }).hostDrv;

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
      # Native builds.
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
          postConfigure =
            pkgs.stdenv.lib.optionalString (pkgs.stdenv.system == "i686-linux")
                                           "export NIX_CFLAGS_COMPILE=-U__i686";

          buildInputs = buildInputsFrom pkgs;

          # FIXME: The `tst-cancelx7' and `tst-cancel7' leave zombies behind
          # them, which prevents the build from completing.
          doCheck = false;

          # Some tests are failing, but we don't want that to prevent "make
          # install".
          checkPhase = "make -k check || true";

          inherit preConfigure meta;
        };

     xbuild_sparc64 = makeCrossBuild {
       # Stolen from $nixpkgs/pkgs/top-level/release-cross.nix.
       config = "sparc64-unknown-linux";
       bigEndian = true;
       arch = "sparc64";
       float = "hard";
       withTLS = true;
       libc = "glibc";
       platform = {
         name = "ultrasparc";
         kernelMajor = "2.6";
         kernelHeadersBaseConfig = "sparc64_defconfig";
         kernelBaseConfig = "sparc64_defconfig";
         kernelArch = "sparc";
         kernelAutoModules = false;
         kernelTarget = "zImage";
         uboot = null;
       };
       gcc.cpu = "ultrasparc";
     };

  };

in jobs
