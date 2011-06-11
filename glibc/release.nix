/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010, 2011  Ludovic Courtès <ludo@gnu.org>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

{ nixpkgs ? ../../nixpkgs
, glibcHurd ? false }:

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
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs; [ gettext_0_17 texinfo perl ];

  succeedOnFailure = true;
  keepBuildDirectory = true;

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

       unset NIX_CROSS_CFLAGS_COMPILE
       unset NIX_CROSS_CFLAGS_LINK
       unset NIX_CROSS_LDFLAGS_BEFORE
       unset NIX_CROSS_LDFLAGS
       unset NIX_CROSS_LDFLAGS_AFTER

       env | grep NIX
    '';

  # Return the right configure flags for `pkgs'.
  configureFlagsFor = pkgs:
    [ "--with-headers=${pkgs.linuxHeaders}/include" ];

  # Cross-compilation jobs.
  makeCrossBuild = glibcPorts: crossSystem:
    { tarball ? jobs.tarball {} }:

    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system crossSystem; };
      crossGNU = (crossSystem.config == "i586-pc-gnu");
      kernelHeaders =
        if crossGNU
        then pkgs.hurdHeaders
        else pkgs.linuxHeadersCross;
      CPATH =
        if crossGNU
        then "${pkgs.hurdHeaders}/include:${pkgs.machHeaders}/include"
        else null;
      extraBuildInputs =
        if crossGNU
        then [ pkgs.mig ]
        else [];
      propagatedBuildNativeInputs =
        if crossGNU
        then [ pkgs.hurdHeaders pkgs.machHeaders ] # XXX: Not really native
        else [];
    in
      (pkgs.releaseTools.nixBuild {
        name = "glibc";
        src = tarball;

        postUnpack =
          pkgs.stdenv.lib.optionalString (glibcPorts != null)
            '' cp -rv "${glibcPorts}" "$sourceRoot/glibc-ports"
            '';

        configureFlags =
          [ "--host=${crossSystem.config}"
            "--with-headers=${kernelHeaders}/include"
            "--enable-kernel=2.6.0"
            "--enable-add-ons"
            "--with-__thread"
            (if crossSystem.withTLS
             then "--with-tls"
             else "--without-tls")
            (if crossSystem.float == "soft"
             then "--without-fp"
             else "--with-fp")
          ];

        buildNativeInputs = (buildInputsFrom pkgs) ++ extraBuildInputs;
        doCheck = false;
        inherit propagatedBuildNativeInputs CPATH preConfigure meta;
      }).hostDrv;

  hurd_patches =
    # Patch set to apply to upstream glibc.
    releaseTools.nixBuild {
      name = "glibc-hurd-patches";
      src = glibcHurd;
      buildInputs = with pkgs; [ git gitAndTools.topGit ];
      phases = "unpackPhase buildPhase";
      buildPhase =
        # Assume Hydra called `nix-prefetch-git', which ran
        # "tg remote --populate origin" (Nixpkgs r26305).
        '' git checkout tschwinge/Roger_Whittaker

           tg info

           # XXX: This method is broken, see
           # <http://lists.gnu.org/archive/html/bug-hurd/2011-03/msg00064.html>.
           #tg export --linearize for-upstream-glibc git checkout
           #for-upstream-glibc git format-patch

           # Do a raw diff against this `baseline' commit.
           git diff ea42a20caed5b343ff20a0d4622ae6c17b77161b > 00-glibc-hurd.patch

           ensureDir "$out"
           mv -v [0-9]*.patch "$out"

           ensureDir "$out/nix-support"
           for patch in "$out/"*.patch
           do
             echo "patch none $patch" >> \
               "$out/nix-support/hydra-build-products"
           done
        '';

      inherit succeedOnFailure keepBuildDirectory;
      meta = meta // { description = "Hurd patches for the GNU C Library"; };
     };

  jobs = rec {

    tarball =
      { glibcSrc ? { outPath = /data/src/glibc; }
      , hurdPatches ? false }:

      releaseTools.sourceTarball ({
	name = "glibc-tarball";
	src = glibcSrc;

        patches =
          (map (x: "${nixpkgs}/pkgs/development/libraries/glibc-2.12/${x}")
               [ "nix-locale-archive.patch"    # NixOS-specific
                 "rpcgen-path.patch"           # submit upstream?
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

        inherit meta succeedOnFailure keepBuildDirectory;
      }

      //

      (if hurdPatches != false
       then {
         postPatch =
           '' for p in ${hurdPatches}/[0-9]*.patch
              do
                echo "applying patch \`$p'..."
                patch --batch -p1 < $p || exit 1
              done
           '';
       }
       else { }));

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

          inherit preConfigure meta succeedOnFailure keepBuildDirectory;
        };

     xbuild_sparc64 =
       makeCrossBuild null crossSystems.sparc64_linux_gnu;

     xbuild_arm =
       { glibcPorts ? null }:

       # ARM support is in glibc-ports.
       assert glibcPorts != null;

       makeCrossBuild glibcPorts crossSystems.armv5tel_linux_gnueabi;

     xbuild_gnu =
       # Cross-build for GNU (aka. GNU/Hurd.)
       makeCrossBuild null crossSystems.i586_pc_gnu;
  }

  //

  (if glibcHurd != false
   then { inherit hurd_patches; }
   else { });

in jobs
