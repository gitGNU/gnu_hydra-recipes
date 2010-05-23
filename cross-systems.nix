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
