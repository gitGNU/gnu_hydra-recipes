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
, hurdSrc ? { outPath = /data/src/hurd/hurd; }
}:

let
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  pkgs = import nixpkgs {};
  xpkgs = import nixpkgs { crossSystem = crossSystems.i586_pc_gnu; };

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

    maintainers = [ pkgs.stdenv.lib.maintainers.ludo ];
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
        buildInputs = [ pkgs.parted /* not the cross-GNU one */ pkgs.libuuid ];
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
          buildInputs = [ pkgs.libuuid pkgs.ncurses ]
            ++ (pkgs.stdenv.lib.optional (parted != null) parted);
          dontPatchShebangs = true;

          patches = [ ./console-run.patch ];

          # Patch absolute paths.
          postPatch =
            '' sed -i daemons/{runttys,getty}.c \
                   -e "s|/bin/login|$out/bin/login|g"

               sed -e 's|/bin/bash|${pkgs.bashInteractive.hostDrv}/bin/bash|g' \
                   -i utils/login.c
            '';
          postInstall =
            '' sed -e 's|/bin/bash|${pkgs.bashInteractive.hostDrv}/bin/bash|g' \
                   -e "s|^PATH=|PATH=$out/bin:$out/sbin:${pkgs.coreutils.hostDrv}/bin:${pkgs.gnused.hostDrv}/bin:/run/current-system/sw/bin:/run/current-system/sw/sbin:|g" \
                   -i "$out/libexec/"{rc,runsystem} "$out/sbin/MAKEDEV"

               sed -e "s|/sbin/fsck|$out/sbin/fsck|g" \
                   -i "$out/libexec/rc"

               sed -e "s|/bin/login|$out/bin/login|g" \
                   -e "s|/bin/fmt|${pkgs.coreutils.hostDrv}/bin/fmt|g" \
                   -i "$out/bin/sush"
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
      , glibcTarball }:

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
              # TODO: Handle `libpthreadCross', `machHeaders', etc. similarly.
              glibcCross =
                 override "glibc" pkgs.glibcCross glibcTarball false;
              hurdCross =
                 override "hurd" pkgs.gnu.hurdCross tarball true;
              hurdHeaders =
                 override "hurd-headers" pkgs.gnu.hurdHeaders tarball true;
              hurdCrossIntermediate =
                 override "hurd-minimal" pkgs.gnu.hurdCrossIntermediate tarball true;
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
          propagatedBuildNativeInputs = [ pkgs.gnu.machHeaders ];
          buildNativeInputs = [ pkgs.gnu.mig ];
          inherit meta succeedOnFailure keepBuildDirectory;
        }).hostDrv;

    # A QEMU disk image with GNU/Hurd on partition 1.
    qemu_image =
      { xbuild ? (jobs.xbuild_without_parted {})
      , mach ? ((import ../gnumach/release.nix {}).build {})
      , coreutils ? xpkgs.coreutils.hostDrv
      , grep ? ((import ../grep/release.nix {}).xbuild_gnu {}) # XXX
      , guile ? xpkgs.guile.hostDrv
      }:

      let
        size = 1024; fullName = "QEMU Disk Image of GNU/Hurd";
        pkgs = import nixpkgs {
          system = "x86_64-linux";               # build platform
          crossSystem = crossSystems.i586_pc_gnu; # host platform
        };

        devices =
          # List of /dev nodes where a translator is to be installed.
          [  "time"
             "null" "full"
             "zero"
             "vcs"
             "tty" "tty1" "tty2" "tty3" "tty4" "tty5" "tty6"
             "fd"
             "mem"
             "klog"
             "shm"
          ];

        servers =
          [ { node = "/servers/socket/1";
              command = "/hurd/pflocal";
            }
            { node = "/servers/password";
              command = "/hurd/password";
            }
          ];

        translatorSetup = with pkgs.lib;
          # Install translators, which cannot be done from GNU/Linux.
          (concatMapStrings (server:
                              '' if ! showtrans -s "${server.node}"
                                 then
                                   settrans -c "${server.node}" ${server.command}
                                 fi
                              '')
                            servers)
          +
          (concatMapStrings (node:
                              '' if [ ! -f "${node}" ] || \
                                    ! showtrans -s "${node}"
                                 then
                                   ( cd /dev ; MAKEDEV "${node}" )
                                 fi
                              '')
                            devices);

        # Software cross-compiled and available in the global environment.
        environment = pkgs.buildEnv {
          name = "gnu-global-user-environment";
          paths = [ mach xbuild coreutils grep guile ]
            ++ (with pkgs;
                map (p: p.hostDrv)
                  [ glibc
                    bashInteractive
                    gnused findutils
                    gcc gnumake
                    less zile
                  ]);
          ignoreCollisions = true;
        };
      in
        pkgs.vmTools.runInLinuxVM (pkgs.stdenv.mkDerivation {
          name = "hurd-qemu-image";
          preVM = pkgs.vmTools.createEmptyImage { inherit size fullName; } +
            ''
               echo "file qemu-image $diskImage" >> \
                 $out/nix-support/hydra-build-products
            '';

          # Command to build the disk image.
          # TODO: console=com0
          buildCommand = let hd = "vda"; dollar = "\\\$"; in ''
            ${pkgs.parted}/sbin/parted /dev/${hd} \
               mklabel msdos mkpart primary ext2 1MiB 750MiB
            mknod /dev/${hd}1 b 254 1

            ${pkgs.e2fsprogs}/sbin/mke2fs -o hurd -F /dev/${hd}1
            mkdir /mnt
            ${pkgs.utillinux}/bin/mount -t ext2 /dev/${hd}1 /mnt

            mkdir -p /mnt/nix/store
            cp -rv "/nix/store/"*-gnu "${environment}" /mnt/nix/store

            # Copy the initial packages whose store path doesn't match *-gnu.
            cp -rv ${pkgs.gnu.hurdHeaders}                                      \
                   ${pkgs.gnu.hurdCrossIntermediate} ${pkgs.gnu.machHeaders}    \
                   ${pkgs.gnu.libpthreadHeaders} ${pkgs.gnu.libpthreadCross}    \
                   /mnt/nix/store

            # Copy `libgcc_s.so' & co.
            cp -rv "${pkgs.gccCrossStageFinal.gccLibs}" /mnt/nix/store

            # The global profile (a symlink tree.)
            mkdir -p /mnt/run/current-system
            ( cd /mnt/run/current-system ; ln -sv ${environment} sw )

            # Set the Nix store to Epoch.
            find /mnt/nix/store -exec touch -d "1970/01/01 00:00 +0000" {} \;

            mkdir /mnt/bin /mnt/dev /mnt/tmp
            ln -sv "${xbuild}/hurd" /mnt/hurd

            ln -sv "${pkgs.bashInteractive.hostDrv}/bin/bash" /mnt/bin/sh

            # Patch /libexec/rc to install essential translators (XXX).
            cp -rv "${xbuild}/libexec" /mnt
            cat >> /mnt/libexec/rc <<EOF
${translatorSetup}
EOF

            # Patch /libexec/runsystem to start the console client.
            sed -i /mnt/libexec/runsystem \
                -e 's|^[[:blank:]]*wait$|console -d vga -d pc_kbd -d generic_speaker /dev/vcs ; wait|g'

            # The Hurd's `fsck' wants /etc/fstab.
            mkdir /mnt/etc
            touch /mnt/etc/fstab
            for i in "${xbuild}/etc/"*
            do
              ( cd /mnt/etc ; ln -sv "$i" )
            done

            # Users.
            cat > /mnt/etc/passwd <<EOF
root:x:0:0:root:/root:${pkgs.bashInteractive.hostDrv}/bin/bash
EOF
            cat > /mnt/etc/shadow <<EOF
root::15174::::::
EOF
            chmod 600 /mnt/etc/shadow
            mkdir /mnt/root

            # Host name.
            echo -n nixognu > /mnt/etc/hostname

            mkdir /mnt/servers
            touch /mnt/servers/{crash,exec,proc,password,default-pager}
            mkdir /mnt/servers/socket
            touch /mnt/servers/socket/{1,2,16}
            ( cd /mnt/servers/socket ;
              ln -s 1 local ; ln -s 2 inet ; ln -s 26 inet6 )

            mkdir -p /mnt/boot/grub
            ln -sv "${mach}/boot/gnumach" /mnt/boot
            cat > /mnt/boot/grub/grub.cfg <<EOF
set timeout=5
search.file /boot/gnumach

menuentry "GNU (wannabe NixOS GNU/Hurd)" {
  multiboot /boot/gnumach root=device:hd0s1
  module  /hurd/ext2fs.static ext2fs \
     --multiboot-command-line='${dollar}{kernel-command-line}' \
     --host-priv-port='${dollar}{host-port}' \
     --device-master-port='${dollar}{device-port}' \
     --exec-server-task='${dollar}{exec-task}' -T typed '${dollar}{root}' \
     '\$(task-create)' '\$(task-resume)'
  module ${pkgs.glibc.hostDrv}/lib/ld.so.1 exec /hurd/exec '\$(exec-task=task-create)'
}
EOF

            ${pkgs.grub2}/sbin/grub-install --no-floppy \
              --boot-directory /mnt/boot /dev/${hd}

            ${pkgs.utillinux}/bin/umount /mnt
          '';
        });
   };
in
  jobs
