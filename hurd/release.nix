/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010, 2011, 2012  Ludovic Courtès <ludo@gnu.org>

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

{ nixpkgs ? <nixpkgs>
, hurdSrc ? { outPath = <hurd>; }
}:

let
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  pkgs = import nixpkgs {};
  xpkgs = import nixpkgs {
    crossSystem = crossSystems.i586_pc_gnu;
  };

  qemuImage = import ./qemu-image.nix;

  meta = {
    description = "The GNU Hurd, GNU project's replacement for the Unix kernel";

    longDescription =
      '' The GNU Hurd is the GNU project's replacement for the Unix kernel.
         It is a collection of servers that run on the Mach microkernel to
         implement file systems, network protocols, file access control, and
         other features that are implemented by the Unix kernel or similar
         kernels (such as Linux).
      '';

    license = "GPLv2+";

    homepage = http://www.gnu.org/software/hurd/;

    maintainers =
      [ "Hurd <commit-hurd@gnu.org>"
        pkgs.stdenv.lib.maintainers.ludo
      ];
  };

  dontStrip = true;
  dontCrossStrip = true;
  NIX_STRIP_DEBUG = 0;

  succeedOnFailure = true;
  keepBuildDirectory = true;

  # Return extra attributes to path absolute paths and add extra features of
  # the Hurd.
  hurdExtraAttrs = pkgs: {
    dontPatchShebangs = true;
    preBuild =
      '' sed -i daemons/{runttys,getty}.c \
             -e "s|/bin/login|$out/bin/login|g"

         sed -e 's|/bin/bash|${pkgs.bashInteractive.hostDrv}/bin/bash|g' \
             -i utils/login.c
      '';
    postBuild = "make hurd.msgids -C hurd"; # for `rpctrace'
    postInstall =
      '' sed -e 's|/bin/bash|${pkgs.bashInteractive.hostDrv}/bin/bash|g' \
             -e "s|^PATH=|PATH=$out/bin:$out/sbin:${pkgs.coreutils.hostDrv}/bin:${pkgs.gnused.hostDrv}/bin:/run/current-system/sw/bin:/run/current-system/sw/sbin:|g" \
             -i "$out/libexec/"{rc,runsystem} "$out/sbin/MAKEDEV"

         sed -e "s|/sbin/fsck|$out/sbin/fsck|g" \
             -i "$out/libexec/rc"

         sed -e "s|/bin/login|$out/bin/login|g" \
             -e "s|/bin/fmt|${pkgs.coreutils.hostDrv}/bin/fmt|g" \
             -i "$out/bin/sush"

         mkdir -p "$out/share/msgids"
         cp -v "hurd/"*.msgids "$out/share/msgids"

         # Last but not least...
         cp -v "console/motd.UTF8" "$out/etc/motd"
      '';
   };

  jobs = {
    tarball =
      # "make dist" should work even non-natively and even without a
      # cross-compiler.  Doing so allows us to catch errors such as shipping
      # MIG-generated or compiled files in the distribution.
      pkgs.releaseTools.sourceTarball {
        name = "hurd-tarball";
        src = hurdSrc;
        postAutoconf = "rm -f svn-revision";  # useless, from `autoconfPhase'
        configureFlags = "--build=i586-pc-gnu";  # cheat

        buildNativeInputs = with pkgs;
          [ git gnu.machHeaders gnu.mig texinfo ];
        buildInputs = with pkgs;
          [ parted /* not the cross-GNU one */
            libuuid
            xorg.libpciaccess               # only needed for the DDE branch.
            texinfo
          ];
        inherit meta succeedOnFailure keepBuildDirectory;
      };

    # Cross build from GNU/Linux.
    xbuild =
      { tarball ? jobs.tarball
      , parted ? (import ../parted/release.nix {}).xbuild_gnu {}
      }:

      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";               # build platform
          crossSystem = crossSystems.i586_pc_gnu; # host platform
        };
      in
        (pkgs.releaseTools.nixBuild ({
          name = "hurd";
          src = tarball;

          postConfigure =
            '' echo "removing \`-o root' from makefiles..."
               for mf in {utils,daemons}/Makefile
               do
                 sed -i "$mf" -e's/-o root//g'
               done
            '';

          propagatedBuildNativeInputs = [ pkgs.gnu.machHeaders ];
          buildNativeInputs = [ pkgs.gnu.mig ];
          buildInputs =
            (with pkgs; [ libuuid ncurses xorg.libpciaccess ])
            ++ (pkgs.stdenv.lib.optional (parted != null) parted);

          enableParallelBuild = true;
          inherit meta succeedOnFailure keepBuildDirectory
            dontStrip dontCrossStrip NIX_STRIP_DEBUG;
        }
        //
        (hurdExtraAttrs pkgs))).hostDrv;

    # Same without dependency on Parted.
    xbuild_without_parted =
      { tarball ? jobs.tarball
      }:

      let
        xbuild = jobs.xbuild { parted = null; inherit tarball; };
      in
        pkgs.lib.overrideDerivation xbuild (attrs: {
          configureFlags = [ "--without-parted" ];
        });

    # Complete cross bootstrap of GNU from GNU/Linux.
    xbootstrap =
      { tarball ? jobs.tarball
      , glibcTarball ? (import ../glibc/release.nix { glibcHurd = <glibc>; }).tarball {}
      , machTarball ? (import ../gnumach/release.nix {}).tarball
      , partedTarball ? ((import ../parted/release.nix {}).tarball {})
      }:

      let
        overrides = import ./overrides.nix {
          inherit machTarball glibcTarball partedTarball;
          hurdTarball = tarball;
        };

        pkgs = import nixpkgs {
          system = "x86_64-linux";               # build platform
          crossSystem = crossSystems.i586_pc_gnu; # host platform
          config.packageOverrides = overrides;
        };
      in
       pkgs.gnu.hurdCross.hostDrv;

    # A QEMU disk image with GNU/Hurd on partition 1.
    qemu_image =
      { xbuild ? (jobs.xbuild_without_parted {})
      , mach ? xpkgs.gnu.mach.hostDrv
      , coreutils ? xpkgs.coreutils.hostDrv
      , inetutils ? ((import ../inetutils/release.nix {}).xbuild_gnu {}) # XXX
      , guile ? xpkgs.guile.hostDrv
      }:

      let
        translators =
          [ { /* SMB share installed by QEMU when run with:
                 "qemu img.qcow2 -net nic -net user,smb=/path/to/shared/dir"  */
              node = "/host";
              command = "${xpkgs.gnu.smbfs.hostDrv}/hurd/smbfs "
                + "-s 10.0.2.4 -r smb://10.0.2.4/qemu -u root -p '' ";
            }
            { node = "/ftp:";
              command = "/hurd/hostmux /hurd/ftpfs /";
            }
          ];

        environment = pkgs:
          [ mach xbuild coreutils inetutils guile ]
          ++ (with pkgs;
              map (p: p.hostDrv)
                [ glibc
                  bashInteractive gnugrep
                  gnused findutils diffutils gawk
                  gcc gdb gnumake nixUnstable
                  less zile
                  gnutar gzip bzip2 xz
                  gnu.mig_raw gnu.smbfs gnu.unionfs
               ])
          ++ [ (pkgs.wget.override { gnutls = null; perl = null; }).hostDrv
               (pkgs.shadow.override { pam = null; }).hostDrv
             ];
      in
        qemuImage {
          pkgs = xpkgs;
          hurd = xbuild;
          inherit mach translators environment;
        };

    # Tests run on GNU in a fresh QEMU image.
    qemu_tests =
      { xbuild ? (jobs.xbuild_without_parted {})
      , mach ? xpkgs.gnu.mach.hostDrv
      , tarball ? jobs.tarball
      , glibcTarball ? (import ../glibc/release.nix { glibcHurd = <glibc>; }).tarball {}
      , machTarball ? (import ../gnumach/release.nix {}).tarball
      , partedTarball ? ((import ../parted/release.nix {}).tarball {})
      }:

      let
        overrides = import ./overrides.nix {
          inherit machTarball glibcTarball partedTarball;
          hurdTarball = tarball;
        };

        pkgs = import nixpkgs {
          crossSystem = crossSystems.i586_pc_gnu;
          config.packageOverrides = overrides;
        };

        vmTools = import ./vm.nix { inherit pkgs; };

        makeTest = name: command:
          vmTools.runOnGNU (pkgs.stdenv.mkDerivation {
            name = "hurd-qemu-test-${name}";
            buildCommand = command;

            diskImage = vmTools.diskImage {
              # XXX: Inherit all the patchwork that fixes absolute paths.
              hurd = pkgs.lib.overrideDerivation pkgs.gnu.hurdCross
                       (attrs: hurdExtraAttrs pkgs);

              inherit mach;
            };

            memSize = 512;                          # GCC is memory-hungry

            meta = meta // {
              # When the kernel debugger is invoked, nothing else happens.
              # So reduce the timeout-on-silence duration to 15 mn (5 mn
              # seems to be insufficient for Coreutils' test suite.)
              maxSilent = 900;
            };
          });
      in
        {
          build = makeTest "build"
            '' echo 'Hey, this operating system works like a charm!'
               echo "Let's see if it can rebuild itself..."

               ( tar xvf "${jobs.tarball}/tarballs/"*.tar.gz ;
                 cd hurd-* ;
                 export PATH="${pkgs.gawk.hostDrv}/bin:$PATH" ;
                 set -e ;
                 ./configure --without-parted --prefix="/host/xchg/out" ;
                 make                             # sequential build
               )

               # FIXME: "make install" not run because `rm' fails on SMBFS.
               mkdir /host/xchg/out

               echo $? > /host/xchg/in-vm-exit
            '';

          parallel_build = makeTest "parallel-build"
            '' echo 'Hey, this operating system works like a charm!'
               echo "Let's see if it can rebuild itself, in parallel!"

               ( tar xvf "${jobs.tarball}/tarballs/"*.tar.gz ;
                 cd hurd-* ;
                 export PATH="${pkgs.gawk.hostDrv}/bin:$PATH" ;
                 set -e ;
                 ./configure --without-parted --prefix="/host/xchg/out" ;
                 make -j4                         # stress it!
               )

               # FIXME: "make install" not run because `rm' fails on SMBFS.
               mkdir /host/xchg/out

               echo $? > /host/xchg/in-vm-exit
            '';

          coreutils =
            { coreutilsTarball
              ? ((import ../coreutils/release.nix {}).tarball {}) }:

            makeTest "coreutils-build"
              '' ( tar xvf "${coreutilsTarball}/tarballs/"*tar.xz ;
                   cd coreutils-* ;
                   set -e ;
                   export FORCE_UNSAFE_CONFIGURE=1 ; # yes, building as root!
                   ./configure --prefix="/host/xchg/out" ;
                   make ;
                   make check VERBOSE=yes )
                 echo $? > /host/xchg/in-vm-exit
              '';
        };


    # The unbelievable crazy thing!
    qemu_image_guile =
      { tarball ? jobs.tarball
      , parted ? (import ../parted/release.nix {}).xbuild_gnu {}
      , mach ? ((import ../gnumach/release.nix {}).build {})
      , coreutils ? xpkgs.coreutils.hostDrv
      , inetutils ? ((import ../inetutils/release.nix {}).xbuild_gnu {}) # XXX
      , guile ? "you really need a cross-GNU Guile" #xpkgs.guile.hostDrv
      }:

      let
        xbuild = jobs.xbuild { inherit tarball parted; };
        hurd = pkgs.lib.overrideDerivation xbuild (attrs: {
          name = "guilish-hurd";

          # Set $SHELL, which is honored by `login' (executing directly
          # `guile' instead of `login' doesn't work, as `login' does
          # important terminal setup.)
          postPatch
            '' echo "Guile is GNU's official shell"'!'
               sed -e 's|^SHELL=.*|SHELL="${guile}/bin/guile"|g' \
                   -i "daemons/runsystem.sh"
            '';
          succeedOnFailure = false;
        });
      in
        jobs.qemu_image {
          xbuild = hurd;
          inherit mach coreutils inetutils guile;
        };
   };
in
  jobs
