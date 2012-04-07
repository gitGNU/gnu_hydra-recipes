/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010, 2011, 2012  Ludovic Courtès <ludo@gnu.org>

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

/* Return a function that overrides the relevant Hurd-related packages with
   the given tarballs.  This allows us to inject tarballs created directly
   off the VCS into Nixpkgs' package composition.  */

{ machTarball, hurdTarball, glibcTarball, partedTarball }:

  pkgs:

  # Override the `src' attribute of the Hurd packages.
  let
    override = pkgName: origPkg: latestPkg: clearPreConfigure:
      builtins.trace "overridding `${pkgName}'..."
      pkgs.makeOverridable (x: x)
      (pkgs.lib.overrideDerivation origPkg (origAttrs: {
        name = "${pkgName}-${latestPkg.version}";
        src = latestPkg;
        patches = [];

        # `sourceTarball' puts tarballs in $out/tarballs, so look there.
        preUnpack =
          ''
            if test -d "$src/tarballs"; then
                src=$(ls -1 "$src/tarballs/"*.tar.bz2 "$src/tarballs/"*.tar.[xg]z | sort | head -1)
            fi
          '';
      }
      //
      (if clearPreConfigure
       then { preConfigure = ":"; }
       else {})));
    new = {
      glibcCross =
         override "glibc" (pkgs.glibcCross.deepOverride {
             kernelHeaders = new.gnu.hurdHeaders;
             inherit (new.gnu) machHeaders hurdHeaders;
           })
           glibcTarball false;

      # XXX: `hurdPartedCross' does `parted.override', but overriding the
      # `parted' attribute doesn't work, so override `hurdPartedCross'
      # directly.
      hurdPartedCross =
         override "parted-hurd" (pkgs.hurdPartedCross.deepOverride {
             hurd = new.gnu.hurdCrossIntermediate;
           })
           partedTarball false;

      gnu = pkgs.gnu.override {
        # Use the new libc and Parted.
        inherit (new) glibcCross hurdPartedCross;

        # We want to override recursively in the `gnu' attribute set,
        # hence the use of the magic `overrides' argument.
        overrides = {
          machHeaders =
             override "gnumach-headers" pkgs.gnu.machHeaders machTarball true;

          hurdHeaders =
             override "hurd-headers" pkgs.gnu.hurdHeaders hurdTarball true;

          hurdCrossIntermediate =
             override "hurd-minimal"
               pkgs.gnu.hurdCrossIntermediate hurdTarball true;

          hurdCross =
             override "hurd" pkgs.gnu.hurdCross hurdTarball true;
        };
      };
    };
  in
    # Return the new, overridden packages.
    new
