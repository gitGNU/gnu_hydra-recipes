/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010, 2011  Ludovic Courtès <ludo@gnu.org>

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
, guilerpcSrc ? { outPath = /data/src/guile-rpc; }
, guile ? (import ../../nixpkgs {}).guile }:

let
  pkgs = import nixpkgs {};

  meta = {
    description = "GNU Guile-RPC, an ONC RPC implementation for Guile";

    longDescription =
      '' GNU Guile-RPC is an implementation of ONC RPC and XDR (standardized
         as RFC 1831 and RFC 4506) in Guile Scheme, and for use by GNU Guile
         programs.  ONC RPC is the "Open Network Computing" Remote
         Procedure Call protocol, allowing programs to invoke procedures of
         programs running on remote machines.  XDR is the underlying binary
         data representation format.
      '';

    license = "LGPLv3+";
    homepage = http://www.gnu.org/software/guile-rpc/;
    maintainers = [ pkgs.lib.maintainers.ludo ];
  };

  jobs = {
    tarball =
      pkgs.releaseTools.sourceTarball {
        name = "guile-rpc";
        src = guilerpcSrc;

        preAutoconf =
          '' version_string="$((git describe || echo git) | sed -es/^v//g | tr - .)"
             sed -i configure.ac \
                 -e "s/^AC_INIT.*$/AC_INIT([guile-rpc], [$version_string], [bug-guile-rpc@gnu.org])/ ;
                     s/check-news//g"
          '';

        buildInputs = [ guile pkgs.texinfo pkgs.git ];
        inherit meta;
      };

    build =
      { tarball ? jobs.tarball }:

      pkgs.releaseTools.nixBuild {
        name = "guile";
        src = tarball;
        buildInputs = [ guile ];
        failureHook =
          '' shopt -o nullglob
             cat /dev/null "tests/"*.log
          '';
        inherit meta;
      };
  };

in
  jobs
