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

with pkgs;

{
  /* Run `drv' on GNU, specifically in `diskImage'.  This is a slightly
     modified version of `runInGenericVM', which expects files to be
     exchanged to be under `xchg'.  */

  runOnGNU = drv: lib.overrideDerivation drv (attrs: with vmTools; {
    requiredSystemFeatures = [ "kvm" ];
    builder = "${bash}/bin/sh";
    args = ["-e" (vmRunCommand qemuCommandGeneric)];
    QEMU_OPTS = "-m ${toString (if attrs ? memSize then attrs.memSize else 256)}";

    preVM = ''
      diskImage=$(pwd)/disk-image.qcow2
      origImage=${attrs.diskImage}
      if test -d "$origImage"; then origImage="$origImage/disk-image.qcow2"; fi
      ${kvm}/bin/qemu-img create -b "$origImage" -f qcow2 $diskImage

      echo "$buildCommand" > xchg/cmd

      eval "$postPreVM"
    '';

    postVM = ''
      cp -prvd xchg/out "$out"
    '';
  });
}
