/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2011, 2012  Ludovic Courtès <ludo@gnu.org>

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

{ pkgs ? (import <nixpkgs> {})
, fullName ? "QEMU Disk Image of GNU/Hurd"
, hurd, mach
, machExtraArgs ? ""                              # example: "console=com0"
, rcExtraCode ? ""                                # appended to /libexec/rc
, environment ? (pkgs: [ mach hurd ]
                  ++ (map (p: p.hostDrv)
                          (with pkgs;
                            [ glibc bashInteractive coreutils
                              findutils gnused gnutar gzip
                              bzip2 diffutils zile less ])))
}:

let
  size = 1024;

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
      { # Networking with QEMU's default settings.
        node = "/servers/socket/2";
        command = "/hurd/pfinet --interface eth0 "
          + "--address 10.0.2.77 "
          + "--netmask 255.255.255.0 "
          + "--gateway 10.0.2.2 "
          + "--ipv6 /servers/socket/16";
      }
      { /* SMB share installed by QEMU when run with:
           "qemu image.qcow2 -net nic -net user,smb=/path/to/shared/dir"  */
        node = "/host";
        command = "${pkgs.gnu.smbfs.hostDrv}/hurd/smbfs "
          + "-s 10.0.2.4 -r smb://10.0.2.4/qemu -u root -p '' "
          + "-w WORKGROUP";
      }
      { node = "/servers/password";
        command = "/hurd/password";
      }
      { node = "/ftp:";
        command = "/hurd/hostmux /hurd/ftpfs /";
      }
      { node = "/servers/crash-dump-core";
        command = "/hurd/crash --dump-core";
      }
      { node = "/servers/crash-kill";
        command = "/hurd/crash --kill";
      }
      { node = "/servers/crash-suspend";
        command = "/hurd/crash --suspend";
      }
    ];

  translatorSetup = with pkgs.lib;
    # Install translators, which cannot be done from GNU/Linux.
    (concatMapStrings (server:
                        '' if ! showtrans -s "${server.node}" &> /dev/null
                           then
                             settrans -c "${server.node}" ${server.command}
                           fi
                        '')
                      servers)
    +
    (concatMapStrings (node:
                        '' if [ ! -f "${node}" ] || \
                              ! showtrans -s "${node}" &> /dev/null
                           then
                             ( cd /dev ; MAKEDEV "${node}" )
                           fi
                        '')
                      devices);


  # Software cross-compiled and available in the global environment.
  userEnvironment = pkgs.buildEnv {
    name = "gnu-global-user-environment";
    paths = environment pkgs;
    ignoreCollisions = true;
  };
in
  assert pkgs.stdenv.cross.config == "i586-pc-gnu";

  pkgs.vmTools.runInLinuxVM (pkgs.stdenv.mkDerivation {
    name = "hurd-qemu-image";
    preVM = pkgs.vmTools.createEmptyImage { inherit size fullName; } +
      ''
         echo "file qemu-image $diskImage" >> \
           $out/nix-support/hydra-build-products
      '';

    # Command to build the disk image.
    buildCommand = let hd = "vda"; dollar = "\\\$"; in ''
      ${pkgs.parted}/sbin/parted /dev/${hd} \
         mklabel msdos mkpart primary ext2 1MiB 750MiB
      mknod /dev/${hd}1 b 254 1

      ${pkgs.e2fsprogs}/sbin/mke2fs -o hurd -F /dev/${hd}1
      mkdir /mnt
      ${pkgs.utillinux}/bin/mount -t ext2 /dev/${hd}1 /mnt

      mkdir -p /mnt/nix/store
      cp -rv "/nix/store/"*-gnu "${userEnvironment}" \
             /mnt/nix/store

      # Copy the Hurd, in case its name doesn't match *-gnu.
      cp -rv "${hurd}" /mnt/nix/store

      # Copy the initial packages whose store path doesn't match *-gnu.
      # The initial `hurdCross' is also needed for those packages that
      # refer to it, such as gdb.
      cp -rv ${pkgs.gnu.hurdHeaders} ${pkgs.gnu.hurdCross}                \
             ${pkgs.gnu.hurdCrossIntermediate} ${pkgs.gnu.machHeaders}    \
             ${pkgs.gnu.libpthreadHeaders} ${pkgs.gnu.libpthreadCross}    \
             /mnt/nix/store

      # Copy `libgcc_s.so' & co.
      cp -rv "${pkgs.gccCrossStageFinal.gccLibs}" /mnt/nix/store

      # The global profile (a symlink tree.)
      mkdir -p /mnt/run/current-system
      ( cd /mnt/run/current-system ; ln -sv ${userEnvironment} sw )

      # Set the Nix store to Epoch.
      find /mnt/nix/store -exec touch -d "1970/01/01 00:00 +0000" {} \;

      mkdir /mnt/bin /mnt/dev /mnt/tmp
      ln -sv "${hurd}/hurd" /mnt/hurd

      ln -sv "${pkgs.bashInteractive.hostDrv}/bin/bash" /mnt/bin/sh

      # Patch /libexec/rc to install essential translators (XXX).
      cp -rv "${hurd}/libexec" /mnt
      cat >> /mnt/libexec/rc <<EOF
${translatorSetup}
${rcExtraCode}
EOF

      # Patch /libexec/runsystem to start the console client.
      sed -i /mnt/libexec/runsystem \
          -e 's|^[[:blank:]]*wait$|console -d vga -d pc_kbd -d generic_speaker /dev/vcs ; wait|g'

      # The Hurd's `fsck' wants /etc/fstab.
      mkdir /mnt/etc
      touch /mnt/etc/fstab
      for i in "${hurd}/etc/"*
      do
        ( cd /mnt/etc ; ln -sv "$i" )
      done

      # Users.
      cat > /mnt/etc/passwd <<EOF
root:x:0:0:root:/root:${pkgs.bashInteractive.hostDrv}/bin/bash
EOF
      cat > /mnt/etc/shadow <<EOF
root::::::::
EOF
      chmod 600 /mnt/etc/shadow
      mkdir /mnt/root

      # Host name.
      echo -n nixognu > /mnt/etc/hostname

      # Networking.
      echo "nameserver 10.0.2.3" > /mnt/etc/resolv.conf
      cp -rv "${pkgs.iana_etc}" /mnt/nix/store
      ( cd /mnt/etc ; for i in "${pkgs.iana_etc}/etc/"* ;
        do ln -sv "$i" ; done )

      mkdir /mnt/servers
      touch /mnt/servers/{exec,proc,password,default-pager} \
            /mnt/servers/crash-{dump-core,kill,suspend}
      ( cd /mnt/servers ; ln -s crash-dump-core crash )
      mkdir /mnt/servers/socket
      touch /mnt/servers/socket/{1,2,16}
      ( cd /mnt/servers/socket ;
        ln -s 1 local ; ln -s 2 inet ; ln -s 26 inet6 )

      mkdir -p /mnt/boot/grub
      ln -sv "${mach}/boot/gnumach" /mnt/boot
      cat > /mnt/boot/grub/grub.cfg <<EOF
set timeout=2
search.file /boot/gnumach

menuentry "GNU (wannabe NixOS GNU/Hurd)" {
multiboot /boot/gnumach root=device:hd0s1 \
  ${machExtraArgs}
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
  })
