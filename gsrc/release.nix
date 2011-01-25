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

/* Expression for packages of the GNU Source Release Collection (SRC).

   The expression mimics that of Nixpkgs but with a selection that contains
   only GNU packages, all built from stable releases.  */

{ nixpkgs ? ../../nixpkgs }:

with (import "${nixpkgs}/pkgs/top-level/release-lib.nix");

mapTestOn {
  acct = linux;
  aspell = linux;
  auctex = linux;
  autoconf = linux;
  #autoconf213 = linux;
  autogen = linux;
  automake = linux;
  automake111x = linux;
  automake19x = linux;
  ballAndPaddle = linux;
  bash = linux;
  bashInteractive = linux;
  binutils = linux;
  bison = linux;
  bison24 = linux;
  ccrtp = linux;
  cflow = linux;
  #classpath = linux;
  coreutils = linux;
  cpio = linux;
  cppi = linux;
  ddd = linux;
  ddrescue = linux;
  dejagnu = linux;
  dico = linux;
  diffutils = linux;
  ed = linux;
  emacs23 = linux;
  emacs23Packages.emms = linux;
  enscript = linux;
  fdisk = linux;
  findutils = linux;
  freefont_ttf = linux;
  fribidi = linux;
  gawk = linux;
  gcc = linux;
  #gcc33 = linux;
  #gcc34 = linux;
  #gcc40 = linux;
  #gcc41 = linux;
  #gcc42 = linux;
  #gcc43 = linux;
  #gcc43_multi = linux;
  #gcc44_real = linux;
  #gccCrossStageStatic = linux;
  #gcj = linux;
  gdb = linux;
  #gdbCross = linux;
  gdbm = linux;
  gengetopt = linux;
  gettext = linux;
  #gfortran = linux;
  #gfortran40 = linux;
  #gfortran41 = linux;
  #gfortran42 = linux;
  #gfortran44 = linux;
  ghostscript = linux;
  ghostscriptX = linux;
  #glibc = linux;
  #glibc211 = linux;
  #glibc25 = linux;
  #glibc29 = linux;
  #glibcLocales = linux;
  global = linux;
  glpk = all;
  gsasl = all;
  gss = all;
  gnash = linux;
  gnat = linux;
  gnuchess = linux;
  gnugrep = linux;
  gnum4 = linux;
  gnumake = linux;
  gnunet = linux;
  gnupatch = linux;
  gnused = linux;
  #gnused_4_2 = linux;
  gnutar = linux;
  gnutls = linux;
  gperf = linux;
  gprolog = linux;
  groff = linux;
  grub2 = linux;
  gsl = linux;
  guile = linux;
  #guileGnome = linux;
  guile_1_9 = linux;
  gv = linux;
  gzip = linux;
  hello = linux;
  icecat3 = linux;
  #icecat3Xul = linux;
  #icecatWrapper = linux;
  #icecatXulrunner3 = linux;
  idutils = linux;
  indent = linux;
  inetutils = linux;
  jwhois = linux;
  libcdio = linux;
  libextractor = linux;
  libgcrypt = linux;
  libiconv = linux;
  libidn = linux;
  libmicrohttpd = linux;
  libsigsegv = linux;
  libtasn1 = linux;
  libtool = linux;
  #libtool_1_5 = linux;
  libunistring = linux;
  libxmi = linux;
  libzrtpcpp = linux;
  lightning = linux;
  lsh = linux;
  mailutils = linux;
  mcron = linux;
  miscfiles = linux;
  mitscheme = linux;
  mkisofs = linux;
  mpfr = linux;
  myserver = linux;
  ncurses = linux;
  nettle = linux;
  parted = linux;
  plotutils = linux;
  pth = linux;
  readline = linux;
  rush = all;
  sharutils = linux;
  texinfo = linux;
  texmacs = linux;
  time = linux;
  tla = linux;
  wget = linux;
  zile = linux;
}
