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

{ nixpkgs ? { outPath = ../../nixpkgs; }
, mpfrSrc ? { outPath = ../../mpfr; }
, gmp ? (import nixpkgs {}).gmp      # native GMP build
, gmp_xgnu ? null                     # cross-GNU GMP build
}:

let
  meta = {
    description = "GNU MPFR";

    longDescription =
      '' The MPFR library is a C library for multiple-precision
         floating-point computations with correct rounding.  MPFR has
         continuously been supported by the INRIA and the current main
         authors come from the Caramel and Arénaire project-teams at Loria
         (Nancy, France) and LIP (Lyon, France) respectively; see more on the
         credit page.  MPFR is based on the GMP multiple-precision library.
      '';

    homepage = http://www.mpfr.org/;

    license = "LGPLv3+";

    maintainers =
     [ "Paul Zimmermann <Paul.Zimmermann@loria.fr>" ];
  };

  preCheck = "export GMP_CHECK_RANDOMIZE=true";

  # The minimum required GMP version.
  old_gmp = pkgs:
    import ../gmp/4.3.2.nix {
      inherit (pkgs) stdenv fetchurl m4;
    };

  # Return true if we should use Valgrind on the given platform.
  useValgrind = stdenv:
    false         # XXX: disabled due to false positives with GMP's newer asm
    || stdenv.system == "x86_64-linux"
    || stdenv.system == "x86_64-darwin";

  jobs =
    import ../gnu-jobs.nix {
      name = "mpfr";
      src  = mpfrSrc;
      inherit nixpkgs meta;
      useLatestGnulib = false;
      enableGnuCrossBuild = true;

      customEnv = {

        tarball = pkgs: {
          buildInputs = [ gmp ]
            ++ (with pkgs; [ xz zip texinfo automake111x perl ]);
          autoconfPhase = "autoreconf -vfi";
          patches = [ ./ck-version-info.patch ];
        };

        build = pkgs: {
          buildInputs = [ gmp ]
            ++ (pkgs.lib.optional (useValgrind pkgs.stdenv) pkgs.valgrind);

          preCheck = preCheck +
            (if useValgrind pkgs.stdenv
             then ''
               export VALGRIND="valgrind -q --error-exitcode=1"
             ''
             else "");
        };

        coverage = pkgs: { buildInputs = [ gmp ]; inherit preCheck; };
        xbuild_gnu = pkgs: { buildInputs = [ gmp_xgnu ]; };
      };
    };
in
  jobs

  //

  {
    # Extra job with `g++' as the C compiler.
    build_with_gxx =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball
      }:

      let
        pkgs  = import nixpkgs { inherit system; };
        build = jobs.build { inherit system tarball; };
      in
        pkgs.releaseTools.nixBuild ({
          src = tarball;
          propagatedBuildInputs = [ gmp ];
          inherit (build) name meta succeedOnFailure keepBuildDirectory;
          inherit preCheck;
          preConfigure =
            '' export CC=g++
               echo "using \`$CC' as the compiler"
            '';
        });

    # Extra job to build with an old GMP.
    build_with_old_gmp =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball
      }:

      let
        pkgs  = import nixpkgs { inherit system; };
        gmp   = old_gmp pkgs;
        build = jobs.build { inherit system tarball; };
      in
        pkgs.releaseTools.nixBuild ({
          src = tarball;
          propagatedBuildInputs = [ gmp ];
          inherit (build) name meta succeedOnFailure keepBuildDirectory;
          inherit preCheck;
        });
   }
