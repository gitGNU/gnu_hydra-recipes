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

{ nixpkgs ? ../../nixpkgs
, binutilsSrc ? { outPath = /data/src/binutils; }
}:

let
  pkgs = import nixpkgs {};

  meta = {
    description = "GNU Binutils, tools for manipulating binaries (linker, assembler, etc.)";

    longDescription = ''
      The GNU Binutils are a collection of binary tools.  The main
      ones are `ld' (the GNU linker) and `as' (the GNU assembler).
      They also include the BFD (Binary File Descriptor) library,
      `gprof', `nm', `strip', etc.
    '';

    homepage = http://www.gnu.org/software/binutils/;

    license = "GPLv3+";

    maintainers = [ pkgs.stdenv.lib.maintainers.ludo ];
  };

  inherit (pkgs) releaseTools;

  checkPhase = "make -k check";
  failureHook =
    '' echo "build failed, dumping log files..."
       for log in $(find -name \*.log)
       do
         echo
         echo "--- $log"
         cat "$log"
       done
    '';

  jobs = rec {

    tarball =
      releaseTools.sourceTarball {
        name = "binutils-tarball";
        src = binutilsSrc;
        autoconfPhase = "true";
        buildInputs = with pkgs;
          [ texinfo gettext flex2535 bison ];

        distPhase =
          ''
             make -f src-release "binutils.tar.bz2"
             ensureDir "$out/tarballs"
             mv -v binutils*.bz2 "$out/tarballs"
          '';
      };

    build =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "binutils";
          src = tarball;

          # FIXME: Looks like some GNU ld tests want libdwarf.
          buildInputs = [ pkgs.dejagnu pkgs.zlib ];

          # When running the test suite, Nixpkgs' ld wrapper isn't used, so
          # the just-built ld needs to be told about library paths.  The
          # `--with-lib-path' option is recognized by `ld/configure' and
          # passsed as LIB_PATH to the DejaGNU machinery.
          configureFlags = "--with-lib-path=${pkgs.zlib}/lib";

          /* FIXME: The ld test suite currently fails because it wrongly
             determines /lib64/ld-linux-x86_64.so as the dynamic linker
             path.  It's `ld/configure.host' that does the job.  The problem
             stems from our GCC (mis)configuration:

             $ gcc --help --verbose 2>&1 | egrep 'ld.*\.so'
             /nix/store/shh00siazqrksamqqn2rm4yyjl4jlxnx-gcc-4.4.3/libexec/gcc/x86_64-unknown-linux-gnu/4.4.3/collect2
             --eh-frame-hdr -m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2 ...

             The fix should probably be in the GCC Nix expression.  */

          inherit meta checkPhase failureHook;
        };

    buildGold =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "binutils-gold";
          src = tarball;
          configureFlags = "--with-lib-path=${pkgs.zlib}/lib --enable-gold";
          buildInputs = with pkgs;
            [ dejagnu zlib flex2535 bison ];

          inherit meta checkPhase failureHook;
        };
  };

in
  jobs
