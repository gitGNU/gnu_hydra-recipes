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
, datamash ? { outPath = <datamash>; }
}:

let
  meta = {
    description = "Command-line calculations and statistical operations";
    longDescription = ''
        GNU Datamash is a command-line program which performs basic
        numeric,textual and statistical operations on input textual data files.
    '';
    homepage = http://www.gnu.org/software/datamash/;

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [
      "Assaf Gordon <assafgordon@gmail.com>"
    ];
  };
in
  import ../gnu-jobs.nix {
    name = "datamash";
    src  = datamash;
    inherit nixpkgs meta;
    enableGnuCrossBuild = true;
    systems = ["x86_64-linux" "i686-linux" "x86_64-darwin"];
    customEnv = {
      tarball = pkgs: {
        dontBuild = false;
        buildInputs = with pkgs; [gettext help2man texinfo git gpref perl];
      };
    };
  }
