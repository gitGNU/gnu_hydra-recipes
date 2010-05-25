/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010  Ludovic Courtès <ludo@gnu.org>

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

/* List of cross-compilation configurations.  Mostly stolen from
   $nixpkgs/pkgs/top-level/release-cross.nix.  */

{ pkgs }:

{
  sparc64_linux_gnu = {
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

  armv5tel_linux_gnueabi = {
    config = "armv5tel-unknown-linux-gnueabi";
    bigEndian = false;
    arch = "arm";
    float = "soft";
    withTLS = true;
    platform = pkgs.platforms.sheevaplug;
    libc = "glibc";
  };

  i586_pc_gnu = {
    config = "i586-pc-gnu";
    bigEndian = false;
    arch = "i586";
    float = "hard";
    withTLS = true;
    platform = pkgs.platforms.pc;
    libc = "glibc";
  };
}
