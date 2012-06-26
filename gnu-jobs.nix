/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2011  Rob Vermaas <rob.vermaas@gmail.com>
   Copyright (C) 2012  Ludovic Courtès <ludo@gnu.org>

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

  jobs = (rec {
    tarball =
      pkgs.releaseTools.makeSourceTarball ({
        name = "${name}-tarball";
        inherit src meta;

        # XXX: Since other jobs refer to this one directly, let's not
        # succeed-on-failure, or these other jobs will get triggered just to
        # fail very quickly.
        succeedOnFailure = false;

        autoconfPhase = ''
          ./bootstrap ${pkgs.lib.optionalString useLatestGnulib "--gnulib-srcdir=../gnulib"} --skip-po --copy
        '';
      }
      // ( pkgs.lib.optionalAttrs useLatestGnulib {
             prePhases = "setupGnulib";
             setupGnulib = ''
               export GNULIB_SRCDIR=../gnulib

               mkdir -p gnulib
               cp -Rv "${<gnulib>}/"* gnulib
               chmod -R 755 gnulib
             '';
           })
      // ( pkgs.lib.optionalAttrs (customEnv ? tarball) (customEnv.tarball pkgs) ) );

    build =
      { system ? builtins.currentSystem }:

      let pkgs = import nixpkgs {inherit system;};
      in with pkgs;
      releaseTools.nixBuild ({
        src = jobs.tarball;

        # Use a low priority on Cygwin.  See
        # <https://github.com/NixOS/hydra/issues/15> for details.
        meta = meta //
          (lib.optionalAttrs stdenv.isCygwin { schedulingPriority = 1; });

        inherit name succeedOnFailure keepBuildDirectory;
      } // ( pkgs.lib.optionalAttrs (customEnv ? build) (customEnv.build pkgs)) );

    coverage =
      pkgs.releaseTools.coverageAnalysis ({
        name = "${name}-coverage";
        src = jobs.tarball;
        inherit meta;
        buildInputs = [];
      } // ( pkgs.lib.optionalAttrs (customEnv ? coverage) (customEnv.coverage pkgs)) );

  } // (pkgs.lib.optionalAttrs enableGnuCrossBuild {
    xbuild_gnu =
      # Cross build to GNU.
      let crosspkgs = import nixpkgs {
            crossSystem = crossSystems.i586_pc_gnu;
          };
      in
      (crosspkgs.releaseTools.nixBuild ({
        src = jobs.tarball;
        doCheck = false;
        inherit name succeedOnFailure keepBuildDirectory;
      }
      //
      (pkgs.lib.optionalAttrs (customEnv ? xbuild_gnu) (customEnv.xbuild_gnu crosspkgs)))).hostDrv;
  }));

in jobs
