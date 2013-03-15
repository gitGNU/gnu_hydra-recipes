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

{ nixpkgs ? ../../nixpkgs
, machSrc ? { outPath = /data/src/hurd/gnumach; rev = 123; } }:

let
  meta = {
    homepage = http://www.gnu.org/software/hurd/;
    description = "GNU Mach, the microkernel used by the GNU Hurd";

    longDescription =
      '' GNU Mach is the microkernel that the GNU Hurd system is based on.

         It is maintained by the Hurd developers for the GNU project and
         remains compatible with Mach 3.0.

         The majority of GNU Mach's device drivers are from Linux 2.0.  They
         were added using glue code, i.e., a Linux emulation layer in Mach.
      '';

    license = "GPLv2+";

    # Those who will receive email notifications.
    maintainers =
      [ "Hurd <commit-hurd@gnu.org>"
        "Ludovic Courtès <ludo@gnu.org>"
      ];
  };

  pkgs = import nixpkgs {};
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  inherit (pkgs) releaseTools;

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = rec {
    tarball =
      releaseTools.sourceTarball {
        name = "gnumach";
        src = machSrc;
        buildInputs = [ pkgs.texinfo ];
        configureFlags = [ "--build=i586-pc-gnu" ]; # cheat
        inherit meta succeedOnFailure keepBuildDirectory;
      };

    build =
      { tarball ? jobs.tarball }:

      let pkgs = import nixpkgs {
            crossSystem = crossSystems.i586_pc_gnu;
          };
      in
        (pkgs.releaseTools.nixBuild {
          name = "gnumach";
          src = tarball;

          patches = [ ./port-deallocate-debug.patch ];

          configureFlags =
            [ # Always enable dependency tracking.  See
              # <http://lists.gnu.org/archive/html/bug-hurd/2010-05/msg00137.html>.
              "--enable-dependency-tracking"

              # Enable the kernel debugger.
              "--enable-kdb"
            ];

          nativeBuildInputs = [ pkgs.gnu.mig ];
          inherit meta succeedOnFailure keepBuildDirectory;
        }).crossDrv;
  };
in
  jobs
