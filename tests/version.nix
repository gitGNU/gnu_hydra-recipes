/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010  Ludovic Courtès <ludo@gnu.org>

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

{ pkgs, ... }:

let
  commands =
    [ "ldd" "touch" "tar" "cpio" "grep" "patch"
      "ifconfig" "guile"
    ];
in
{
  machine = { config, pkgs, ... }: {
    # Extra packages wanted in the global environment.
    environment.systemPackages =
      [ pkgs.cpio pkgs.guile_1_9 pkgs.inetutils ];
  };

  testScript =
    ''
       ${pkgs.lib.concatMapStrings
           (cmd: "$machine->mustSucceed(\"${cmd} --version >&2\");")
           commands}

       $machine->mustSucceed("guile -c '(format #t \"hello, world!~%\")' >&2");
    '';
}
