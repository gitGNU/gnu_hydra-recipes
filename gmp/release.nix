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
, gmpSrc ? { outPath = ../../gmp; } }:

let
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

    maintainers =
     [ (import nixpkgs {}).stdenv.lib.maintainers.ludo
     ];
  };

  buildInputsFrom = pkgs: [ pkgs.gnum4 ];
in
  import ../gnu-jobs.nix {
    name = "gmp";
    src  = gmpSrc;
    inherit nixpkgs meta;
    useLatestGnulib = false;
    enableGnuCrossBuild = true;

    customEnv = {

      tarball = pkgs: {
	buildInputs = (buildInputsFrom pkgs)
          ++ (with pkgs; [ texinfo automake111x ]);
        autoconfPhase = "./.bootstrap";
      };

      build = pkgs: {
        preConfigure =
          '' rm -v config.guess
             ln -sv configfsf.guess config.guess
          '';
        buildInputs = (buildInputsFrom pkgs);
      };

      coverage = pkgs: { buildInputs = (buildInputsFrom pkgs); };
      xbuild_gnu = pkgs: { buildInputs = (buildInputsFrom pkgs); };
    };
  }
