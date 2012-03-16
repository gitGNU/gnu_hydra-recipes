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
      [ "Thomas Schwinge <thomas@schwinge.name>"
        pkgs.stdenv.lib.maintainers.ludo
      ];
  };

  dontStrip = true;
  dontCrossStrip = true;
  NIX_STRIP_DEBUG = 0;

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = {
    tarball =
      # "make dist" should work even non-natively and even without a
      # cross-compiler.  Doing so allows us to catch errors such as shipping
      # MIG-generated or compiled files in the distribution.
      pkgs.releaseTools.sourceTarball {
        name = "hurd-tarball";
        src = hurdSrc;
        configureFlags = "--build=i586-pc-gnu";  # cheat
        postConfigure =
          '' echo "removing \`-o root' from makefiles..."
             for mf in {utils,daemons}/Makefile
             do
               sed -i "$mf" -e's/-o root//g'
             done
          '';
        buildNativeInputs = with pkgs; [ gnu.machHeaders gnu.mig texinfo ];
        buildInputs = with pkgs;
          [ parted /* not the cross-GNU one */
            libuuid
            xorg.libpciaccess               # only needed for the DDE branch.
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
        (pkgs.releaseTools.nixBuild {
          name = "hurd";
          src = tarball;
          propagatedBuildNativeInputs = [ pkgs.gnu.machHeaders ];
          buildNativeInputs = [ pkgs.gnu.mig ];
          buildInputs =
            (with pkgs; [ libuuid ncurses xorg.libpciaccess ])
            ++ (pkgs.stdenv.lib.optional (parted != null) parted);
          dontPatchShebangs = true;

          patches = [ ./console-run.patch ./console-server-utf8.patch ];

          # Patch absolute paths.
          postPatch =
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

          enableParallelBuild = true;
          inherit meta succeedOnFailure keepBuildDirectory
            dontStrip dontCrossStrip NIX_STRIP_DEBUG;
        }).hostDrv;

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
        overrideHurdPackages = pkgs:

          # Override the `src' attribute of the Hurd packages.
          let
            override = pkgName: origPkg: latestPkg: clearPreConfigure:
              builtins.trace "overridding `${pkgName}'..."
              (pkgs.lib.overrideDerivation origPkg (origAttrs: {
                name = "${pkgName}-${latestPkg.version}";
                src = latestPkg;
                patches = [];

                # `sourceTarball' puts tarballs in $out/tarballs, so look there.
                preUnpack =
                  ''
                    if test -d "$src/tarballs"; then
                        src=$(ls -1 "$src/tarballs/"*.tar.bz2 "$src/tarballs/"*.tar.gz | sort | head -1)
                    fi
                  '';
              }
              //
              (if clearPreConfigure
               then { preConfigure = ":"; }
               else {})));
          in
            {
              # TODO: Handle `libpthreadCross', etc. similarly.
              glibcCross =
                 override "glibc" pkgs.glibcCross glibcTarball false;

              hurdPartedCross =
                 override "parted" pkgs.hurdPartedCross partedTarball false;

              gnu = pkgs.gnu // {
                hurdCross =
                   override "hurd" pkgs.gnu.hurdCross tarball true;
                hurdHeaders =
                   override "hurd-headers" pkgs.gnu.hurdHeaders tarball true;
                hurdCrossIntermediate =
                   override "hurd-minimal"
                     pkgs.gnu.hurdCrossIntermediate tarball true;
                machHeaders =
                   override "gnumach-headers"
                     pkgs.gnu.machHeaders machTarball true;
              };
            };

        pkgs = import nixpkgs {
          system = "x86_64-linux";               # build platform
          crossSystem = crossSystems.i586_pc_gnu; # host platform
          config = { packageOverrides = overrideHurdPackages; };
        };
      in
        (pkgs.releaseTools.nixBuild {
          name = "hurd";
          src = tarball;
          propagatedBuildNativeInputs = with pkgs;
            [ gnu.machHeaders hurdPartedCross ];
          buildNativeInputs = [ pkgs.gnu.mig ];
          inherit meta succeedOnFailure keepBuildDirectory;
        }).hostDrv;

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

    qemu_test =
      { xbuild ? (jobs.xbuild_without_parted {})
      , mach ? xpkgs.gnu.mach.hostDrv
      }:

      let
        vmTools = import ./vm.nix { pkgs = xpkgs; };
      in
        vmTools.runOnGNU (xpkgs.stdenv.mkDerivation {
          name = "hurd-qemu-test";
          buildCommand =
            '' echo 'Hey, this operating system works like a charm!'
               echo "Let's see if it can rebuild itself..."

               ( tar xvf "${jobs.tarball}/tarballs/"*.tar.gz ;
                 cd hurd-* ;
                 export PATH="${xpkgs.gawk.hostDrv}/bin:$PATH" ;
                 set -e ;
                 ./configure --without-parted --prefix="/host/xchg/out" ;
                 make -j4                         # stress it!
               )

               # FIXME: "make install" not run because `rm' fails on SMBFS.
               mkdir /host/xchg/out

               echo $? > /host/xchg/in-vm-exit
            '';
          diskImage = vmTools.diskImage {
            hurd = xbuild;
            inherit mach;
          };

          meta = meta // {
            # When the kernel debugger is invoked, nothing else happens.  So
            # reduce the timeout-on-silence duration to 5 mn.
            maxSilent = 300;
          }
        });

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
          postPatch = attrs.postPatch + ''
            echo "Guile is GNU's official shell"'!'
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
