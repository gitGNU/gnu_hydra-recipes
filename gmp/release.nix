/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2011, 2012, 2013, 2014  Ludovic Courtès <ludo@gnu.org>

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

let
  nixpkgs = <nixpkgs>;

  meta = {
    description = "The GNU Multiple Precision Arithmetic Library (GMP)";

    longDescription =
      '' GMP is a free library for arbitrary precision arithmetic, operating
         on signed integers, rational numbers, and floating point numbers.
         There is no practical limit to the precision except the ones implied
         by the available memory in the machine GMP runs on.  GMP has a rich
         set of functions, and the functions have a regular interface.
      '';

    homepage = http://gmplib.org/;

    license = "LGPLv3+";

    # Those who will receive email notifications.
    maintainers = [];
  };

  buildInputsFrom = pkgs: [ pkgs.gnum4 ];
  configureFlagsFor = stdenv:
    [ "--enable-cxx" "--enable-alloca=debug" ]
    ++ (stdenv.lib.optional (   stdenv.system == "x86_64-linux"
                             || stdenv.system == "i686-linux"
                             || stdenv.system == "x86_64-freebsd")
          [ "--enable-fat" ])

    # DLLs fail to build on Cygwin, so don't even try.
    ++ (stdenv.lib.optionals stdenv.isCygwin
          [ "--disable-shared" "--enable-static" ]);
in
  import ../gnu-jobs.nix {
    name = "gmp";
    src  = <gmp>;
    inherit nixpkgs meta;
    useLatestGnulib = false;
    enableGnuCrossBuild = true;

    systems = ["i686-freebsd" "i686-solaris" "x86_64-darwin" "x86_64-linux" "i686-linux" "x86_64-freebsd"];

    customEnv = {

      tarball = pkgs: {
	buildInputs = (buildInputsFrom pkgs)
          ++ (with pkgs; [ texinfo automake111x bison flex ]);
        autoconfPhase = "./.bootstrap";
        configureFlags = [ "--enable-maintainer-mode" ];
      };

      build = pkgs: {
        buildInputs = (buildInputsFrom pkgs);
        configureFlags = configureFlagsFor pkgs.stdenv;
      };

      coverage = pkgs: {
        buildInputs = (buildInputsFrom pkgs);
        configureFlags = configureFlagsFor pkgs.stdenv;
      };

      xbuild_gnu = pkgs: {
        nativeBuildInputs = (buildInputsFrom pkgs);
        configureFlags = configureFlagsFor pkgs.stdenv;
      };
    };
  }
