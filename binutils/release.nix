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

  checkPhase =
    # The `ld' test suite assumes that zlib and libstdc++ are in the loader's
    # search path, so help it.
    let dollar = "\$"; in
    '' export LD_LIBRARY_PATH="${pkgs.zlib}/lib${dollar}{LD_LIBRARY_PATH+:}$LD_LIBRARY_PATH"
       export LD_LIBRARY_PATH="$(dirname $(gcc -print-file-name=libstdc++.so)):$LD_LIBRARY_PATH"
       echo "\$LD_LIBRARY_PATH is \`$LD_LIBRARY_PATH'"
       make -k check
    '';

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = rec {

    tarball =
      releaseTools.sourceTarball {
        name = "binutils-tarball";
        src = binutilsSrc;
        autoconfPhase = "true";
        buildInputs = with pkgs;
          [ texinfo gettext_0_17 flex2535 bison ];

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

          inherit meta checkPhase succeedOnFailure keepBuildDirectory;
        };

    build_gold =
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
            [ dejagnu zlib flex2535 bison

              # Some Gold tests require this:
              bc
            ];

          inherit meta checkPhase succeedOnFailure keepBuildDirectory;
        };
  };

in
  jobs
