/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010, 2011  Ludovic Courtès <ludo@gnu.org>
   Copyright (C) 2010  Rob Vermaas <rob.vermaas@gmail.com>

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
, partedSrc ? { outPath = ../../parted; } }:

let
  meta = {
    description = "GNU Parted, a tool to create, destroy, resize, check, and copy partitions";

    longDescription = ''
      GNU Parted is an industrial-strength package for creating, destroying,
      resizing, checking and copying partitions, and the file systems on
      them.  This is useful for creating space for new operating systems,
      reorganising disk usage, copying data on hard disks and disk imaging.

      It contains a library, libparted, and a command-line frontend, parted,
      which also serves as a sample implementation and script backend.
    '';

    homepage = http://www.gnu.org/software/parted/;
    license = "GPLv3+";

    maintainers = [
    ];

    # GNU Parted requires libuuid, which is part of util-linux-ng.
    platforms = (import nixpkgs {}).stdenv.lib.platforms.linux;
  };

  buildInputsFrom = pkgs: with pkgs;
    [ devicemapper libuuid gettext_0_18 readline check ];

in
  import ../gnu-jobs.nix {
    name = "parted";
    src  = partedSrc;
    inherit nixpkgs meta; 
    enableGnuCrossBuild = true;
    
    customEnv = {
        
      tarball = pkgs: {
        buildInputs = with pkgs; [ git xz texinfo automake111x perl rsync gperf man cvs pkgconfig ] ++ buildInputsFrom pkgs;
      } ;
      
      build = pkgs: {
        buildInputs = buildInputsFrom pkgs;
        preCheck =
          # Some tests assume `mkswap' is in $PATH.
          '' export PATH="${pkgs.utillinuxng}/sbin:$PATH"
          '';
      };
      
      coverage = pkgs: {
        buildInputs = buildInputsFrom pkgs;
        preCheck =
          # Some tests assume `mkswap' is in $PATH.
          '' export PATH="${pkgs.utillinuxng}/sbin:$PATH"
          '';
      };
      
      xbuild_gnu = pkgs: {
        buildInputs = with pkgs; [ readline libuuid hurdCross ];
        buildNativeInputs = with pkgs; [ gettext_0_18 ];
        configureFlags =
          [ "--disable-device-mapper"
            "--enable-static" # The Hurd wants libparted.a
          ];
      };
      
    };   
  }
