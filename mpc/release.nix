/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2011, 2012, 2014  Ludovic Courtès <ludo@gnu.org>

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

{ gmp ? (import <nixpkgs> {}).gmp      # native GMP build
, gmp_xgnu ? null                     # cross-GNU GMP build
, mpfr ? (import <nixpkgs> {}).mpfr    # native MPFR build
, mpfr_xgnu ? null                    # cross-GNU MPFR build
}:

let
  # Systems we want to build for.
  systems = [ "x86_64-linux" "i686-linux" "x86_64-freebsd"
              "x86_64-darwin" "i686-sunos" "i686-cygwin" ];

  meta = {
    description = "GNU MPC, a library for multi-precision complex numbers";

    longDescription =
      '' GNU MPC is a C library for the arithmetic of complex numbers with
         arbitrarily high precision and correct rounding of the result. It is
         built upon and follows the same principles as GNU MPFR.
      '';

    homepage = http://mpc.multiprecision.org/;

    license = "LGPLv3+";

    maintainers = [  "Andreas Enge <andreas.enge@inria.fr>" ];
  };

  pkgs = import <nixpkgs> {};

  succeedOnFailure = true;
  keepBuildDirectory = true;

  preCheck = "export GMP_CHECK_RANDOMIZE=true";

  # Return true if we should use Valgrind on the given platform.
  useValgrind = stdenv: stdenv.isLinux || stdenv.isDarwin;

  # The minimum required GMP & MPFR versions.

  old_gmp = pkgs:
    import ../gmp/4.3.2.nix {
      inherit (pkgs) stdenv fetchurl m4;
    };

  old_mpfr = pkgs:
    import ../mpfr/3.0.0.nix {
      inherit (pkgs) stdenv fetchurl;
      gmp = old_gmp pkgs;
    };

  jobs = {
    tarball =
      let pkgs = import <nixpkgs> {}; in
      pkgs.releaseTools.sourceTarball {
        name = "mpc-tarball";
        src  = <mpc>;
        buildInputs = [ gmp mpfr ]
          ++ (with pkgs; [ subversion texinfo automake111x ]);
        autoconfPhase = "autoreconf -vfi";
        inherit meta succeedOnFailure keepBuildDirectory;
      };

    build =
      pkgs.lib.genAttrs systems (system:

      let pkgs = import <nixpkgs> { inherit system; }; in
      pkgs.releaseTools.nixBuild ({
        name = "mpc";
        src = jobs.tarball;

        preConfigure =
           if useValgrind pkgs.stdenv
           then ''
             export VALGRIND_SUPPRESSION="${./gmp-icore2.supp}"
             echo "using \`$VALGRIND_SUPPRESSION' as valgrind suppression file"
           ''
           else "";

        configureFlags =
          # On Cygwin GMP is compiled statically, so build MPC statically.
          (pkgs.stdenv.lib.optionals pkgs.stdenv.isCygwin
            [ "--enable-static" "--disable-shared" ])

          ++ (pkgs.lib.optional (useValgrind pkgs.stdenv)
                "--enable-valgrind-tests");

        buildInputs = [ gmp mpfr ]
          ++ (pkgs.lib.optional (useValgrind pkgs.stdenv) pkgs.valgrind);

        inherit meta preCheck succeedOnFailure keepBuildDirectory;
      }
      //
      # Make sure GMP is found on Solaris
      # (see <http://hydra.nixos.org/build/2764423>).
      (pkgs.stdenv.lib.optionalAttrs pkgs.stdenv.isSunOS {
        CPPFLAGS = "-I${mpfr}/include -I${gmp}/include";
        LDFLAGS = "-L${mpfr}/lib -L${gmp}/lib";
      })));

    coverage =
      { tarball ? jobs.tarball }:

      let pkgs = import <nixpkgs> { /* x86_64-linux */ }; in
      pkgs.releaseTools.coverageAnalysis {
        name = "mpc-coverage";
        src = tarball;
        CPPFLAGS = "-DNDEBUG=1";               # disable assertions
        buildInputs = [ gmp mpfr ];
        inherit preCheck meta succeedOnFailure keepBuildDirectory;
      };

    # xbuild_gnu =
    #   { tarball ? jobs.tarball }:

    #   let
    #     pkgs = import <nixpkgs> {};
    #     crossSystems = (import ../cross-systems.nix) { inherit pkgs; };
    #     xpkgs = import nixpkgs {
    #       crossSystem = crossSystems.i586_pc_gnu;
    #     };
    #   in
    #   (xpkgs.releaseTools.nixBuild {
    #     name = "mpc-gnu";
    #     src = tarball;
    #     buildInputs = [ gmp_xgnu mpfr_xgnu ];
    #     inherit meta succeedOnFailure keepBuildDirectory;
    #   }).crossDrv;

    build_gxx =
      { system ? builtins.currentSystem
      , tarball ? jobs.tarball
      }:

      let
        pkgs = import <nixpkgs> { inherit system; };
        build = jobs.build { inherit system tarball; };
      in
        # Prepare a variant of the `build' job.
        pkgs.lib.overrideDerivation build (attrs: {
          name = "mpc-gxx";

          # Disable Valgrind tests.
          configureFlags =
            attrs.configureFlags ++ [ "--disable-valgrind-tests" ];
          nativeBuildInputs =
            (pkgs.lib.filter (x: x != pkgs.valgrind) attrs.nativeBuildInputs);

          preConfigure =
             ''
               export CC=g++
               echo "using \`$CC' as the compiler"
             '';
        });

    # Extra job to build with an MPFR that uses an old GMP & an old MPFR.
    build_with_old_gmp_mpfr =
      { system ? builtins.currentSystem
      , tarball ? jobs.tarball
      }:

      let
         pkgs  = import <nixpkgs> { inherit system; };
         gmp   = old_gmp pkgs;
         mpfr  = old_mpfr pkgs;
         build = jobs.build { inherit system; };
      in
         pkgs.releaseTools.nixBuild ({
            name = "mpc-oldgmpmpfr";
            src = tarball;
            buildInputs = [ gmp mpfr ];
            inherit (build) meta configureFlags preCheck
               succeedOnFailure keepBuildDirectory;
         }
         //
         # Make sure GMP is found on Solaris
         (pkgs.stdenv.lib.optionalAttrs pkgs.stdenv.isSunOS {
         CPPFLAGS = "-I${mpfr}/include -I${gmp}/include";
         LDFLAGS = "-L${mpfr}/lib -L${gmp}/lib";
         }));
   };
in
  jobs
