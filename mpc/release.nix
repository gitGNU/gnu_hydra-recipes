/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2011  Ludovic Courtès <ludo@gnu.org>

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
, mpcSrc ? { outPath = ../../mpc; }
, gmp ? (import nixpkgs {}).gmp      # native GMP build
, gmp_xgnu ? null                     # cross-GNU GMP build
, mpfr ? (import nixpkgs {}).mpfr    # native MPFR build
, mpfr_xgnu ? null                    # cross-GNU MPFR build
}:

let
  meta = {
    description = "GNU MPC, a library for multi-precision complex numbers";

    longDescription =
      '' GNU MPC is a C library for the arithmetic of complex numbers with
         arbitrarily high precision and correct rounding of the result. It is
         built upon and follows the same principles as GNU MPFR.
      '';

    homepage = http://mpc.multiprecision.org/;

    license = "LGPLv3+";

    maintainers =
      [ "Paul Zimmermann <Paul.Zimmermann@loria.fr>"
        "Andreas Enge <andreas.enge@inria.fr>"
      ];
  };

  preCheck = "export GMP_CHECK_RANDOMIZE=true";

  # Return true if we should use Valgrind on the given platform.
  useValgrind = stdenv: stdenv.isLinux;

  jobs =
    import ../gnu-jobs.nix {
      name = "mpc";
      src  = mpcSrc;
      inherit nixpkgs meta;
      useLatestGnulib = false;
      enableGnuCrossBuild = true;

      customEnv = {

        tarball = pkgs: {
          buildInputs = [ gmp mpfr ]
            ++ (with pkgs; [ subversion texinfo automake111x ]);
          autoconfPhase = "autoreconf -vfi";
        };

        build = pkgs: {
          configureFlags =
            # On Cygwin GMP is compiled statically, so build MPC statically.
            (pkgs.stdenv.lib.optionals pkgs.stdenv.isCygwin
              [ "--enable-static" "--disable-shared" ])

            ++ (pkgs.lib.optional (useValgrind pkgs.stdenv)
                  "--enable-valgrind-tests");

          buildInputs = [ gmp mpfr ]
            ++ (pkgs.lib.optional (useValgrind pkgs.stdenv) pkgs.valgrind);

          inherit preCheck;
        };
        coverage = pkgs: { buildInputs = [ gmp mpfr ]; inherit preCheck; };
        xbuild_gnu = pkgs: { buildInputs = [ gmp_xgnu mpfr_xgnu ]; };
      };
    };
in
  jobs

  //

  {
    # Extra job to build with an MPFR that uses an old GMP.
    build_with_mpfr_with_old_gmp =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball
      , mpfr_with_old_gmp
      }:

      let
        pkgs  = import nixpkgs { inherit system; };
        gmp   = mpfr_with_old_gmp.passthru.gmp;
        build = jobs.build {};
      in
        pkgs.releaseTools.nixBuild ({
          src = tarball;
          buildInputs = [ gmp mpfr_with_old_gmp ];
          inherit (build) name meta configureFlags preCheck
            succeedOnFailure keepBuildDirectory;
        });
   }
