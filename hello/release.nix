/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2012, 2013  Rob Vermaas <rob.vermaas@gmail.com>

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

{ nixpkgs ? <nixpkgs>
, hello ? { outPath = <hello>; }
}:

let
  meta = {
    description = "A program that produces a familiar, friendly greeting";
    longDescription = ''
      GNU Hello is a program that prints "Hello, world!" when you run it.
      It is fully customizable.
    '';
    homepage = http://www.gnu.org/software/hello/manual/;

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [
      "Reuben Thomas <rrt@sc3d.org>"
      "Sami Kerola <kerolasa@iki.fi>"
    ];
  };
in
  import ../gnu-jobs.nix {
    name = "hello";
    src  = hello;
    inherit nixpkgs meta;
    enableGnuCrossBuild = true;
    systems = ["x86_64-linux" "i686-linux" "x86_64-darwin" "x86_64-freebsd"];
    customEnv = {
      tarball = pkgs: {
        dontBuild = false;
        buildInputs = with pkgs; [gettext help2man texinfo];
      };
    };
  }
