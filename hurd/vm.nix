/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2012  Ludovic Courtès <ludo@gnu.org>
   Copyright (C) 2008, 2009, 2010, 2011, 2012 Eelco Dolstra
   Copyright (C) 2008, 2009, 2010, 2011, 2012 Rob Vermaas

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

{ pkgs }:

assert pkgs.stdenv.cross != null
 && pkgs.stdenv.cross.config == "i586-pc-gnu";

let userPkgs = pkgs; in
{
  /* The default GNU image, used for testing.  */

  diskImage =
    { pkgs ? userPkgs
    , mach ? pkgs.gnu.mach
    , hurd ? pkgs.gnu.hurdCross
    , size ? 1024                                 # image size in MiB
    }:

    let
      translators =
        [ # SMB shares installed by `runOnGNU'.
          { node = "/host/xchg";
            command = "${pkgs.gnu.smbfs.crossDrv}/hurd/smbfs "
              + "-s 10.0.2.4 -r smb://10.0.2.4/xchg -u root -p ''";
          }
          { node = "/host/store";
            command = "${pkgs.gnu.smbfs.crossDrv}/hurd/smbfs "
              + "-s 10.0.2.4 -r smb://10.0.2.4/store -u root -p ''";
          }
        ];
      environment = pkgs:
        [ mach hurd ]
        ++ (with pkgs;
            map (p: p.crossDrv)
             [ gnused gnugrep findutils diffutils
               bash gcc gnumake gawk
               gnutar gzip bzip2 xz
               gnu.mig_raw gnu.smbfs gnu.unionfs
             ]);
    in
      import ./qemu-image.nix {
        machExtraArgs = "console=com0";
        rcExtraCode =
          '' set -x
             uname -a
             ls -la /host/xchg
             if [ -f /host/xchg/cmd ]
             then
                 source /host/xchg/cmd
             fi
             reboot
          '';
        inherit pkgs mach hurd translators environment size;
      };

  /* Run `drv' on GNU, specifically in `diskImage'.  This is a slightly
     modified version of `runInGenericVM', which expects files to be
     exchanged to be under `xchg'.  */

  runOnGNU = drv:
    let
      # Use a patched QEMU-KVM to export multiple SMB shares to the guest.
      kvm = pkgs.lib.overrideDerivation pkgs.qemu_kvm (attrs: {
        patches =
          (pkgs.lib.optional (attrs ? patches) attrs.patches)
          ++ [ ./qemu-multiple-smb-shares.patch ];
      });

      # The command to run our modified QEMU-KVM with SMB shares set up.
      qemuCommand =
        ''
           PATH="${pkgs.samba}/sbin:$PATH"                      \
           ${kvm}/bin/qemu-system-x86_64 -nographic -no-reboot  \
             -smb $(pwd) -hda $diskImage $QEMU_OPTS
        '';
    in
      pkgs.lib.overrideDerivation drv (attrs:
        let diskImage =
              if (attrs ? diskImage) then attrs.diskImage else diskImage {};
        in {
          requiredSystemFeatures = [ "kvm" ];
          builder = "${pkgs.bash}/bin/sh";
          args = ["-e" (pkgs.vmTools.vmRunCommand qemuCommand)];
          QEMU_OPTS = "-m ${toString (if attrs ? memSize then attrs.memSize else 256)}";

          inherit diskImage;

          # Pull in the build inputs of the disk image, so that they are
          # visible in the store, which then allows the host's store to be
          # used directly as the guest's store.
          diskImageBuildInputs = diskImage.prerequisites;

          preVM = ''
            diskImage=$(pwd)/disk-image.qcow2
            origImage="${diskImage}"
            if test -d "$origImage"; then origImage="$origImage/disk-image.qcow2"; fi
            ${kvm}/bin/qemu-img create -b "$origImage" -f qcow2 $diskImage

            # XXX: Until the guest's /nix/store is a unionfs of its actual
            # store and the host's one (i.e., when both unionfs and smbfs
            # implement `io_map', so that ld.so can load binaries off them),
            # rewrite store paths.
            echo "$buildCommand" | \
              ${pkgs.gnused}/bin/sed -r \
                -e's|/nix/store/([0-9a-z]{32})-([^ ]+)|/host/store/\1-\2|g' \
              > xchg/cmd

            eval "$postPreVM"
          '';

          postVM = ''
            cp -prvd xchg/out "$out"
          '';
        });
}
