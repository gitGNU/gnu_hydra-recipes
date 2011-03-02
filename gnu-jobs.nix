/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2011  Rob Vermaas <rob.vermaas@gmail.com>

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

{ meta
, name
, src
, customEnv
, customJobs ? pkgs: {}
, nixpkgs
, enableGnuCrossBuild ? false
, useLatestGnulib ? true
}:
    
let
  pkgs = import nixpkgs {};
  crossSystems = (import ./cross-systems.nix) { inherit pkgs; };

  succeedOnFailure = true;
  keepBuildDirectory = true;

  tarballFun = gnulib :
      pkgs.releaseTools.makeSourceTarball ({
        name = "${name}-tarball";
        inherit src meta succeedOnFailure keepBuildDirectory;

        prePhases = "setupGnulib";
        setupGnulib = pkgs.lib.optionalString useLatestGnulib ''
          export GNULIB_SRCDIR=../gnulib

          mkdir -p gnulib
          cp -Rv "${gnulib}/"* gnulib
          chmod -R 755 gnulib
        '';

        autoconfPhase = ''
          ./bootstrap ${pkgs.lib.optionalString useLatestGnulib "--gnulib-srcdir=../gnulib"} --skip-po --copy
        '';
      } // ( pkgs.lib.optionalAttrs (customEnv ? tarball) (customEnv.tarball pkgs) ) );

  jobs = (rec {
    tarball = 
      if useLatestGnulib then { gnulib ? {outPath = ../gnulib;} }: tarballFun gnulib else tarballFun null;

    build =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball {}
      }:
      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild ({
        src = tarball;
        inherit name meta succeedOnFailure keepBuildDirectory;
      } // ( pkgs.lib.optionalAttrs (customEnv ? build) (customEnv.build pkgs)) );

    coverage =
      { tarball ? jobs.tarball {}
      }:
      with pkgs;

      releaseTools.coverageAnalysis ({
        name = "${name}-coverage";
        src = tarball;
        inherit meta;
        buildInputs = [];
      } // ( pkgs.lib.optionalAttrs (customEnv ? coverage) (customEnv.coverage pkgs)) );

  } // (pkgs.lib.optionalAttrs enableGnuCrossBuild {
    xbuild_gnu =
      # Cross build to GNU.
      { tarball ? jobs.tarball {}
      }:

      let crosspkgs = import nixpkgs {
            crossSystem = crossSystems.i586_pc_gnu;
          };
      in
      (crosspkgs.releaseTools.nixBuild ({
        inherit name ;
        src = tarball;
        doCheck = false;
      } // ( pkgs.lib.optionalAttrs (customEnv ? xbuild_gnu) (customEnv.xbuild_gnu crosspkgs)) ) ).hostDrv;      
  }));

in jobs
