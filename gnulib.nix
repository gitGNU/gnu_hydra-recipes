/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009  Rob Vermaas <rob.vermaas@gmail.com>

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

pkgs:
pkgs.fetchgit {
  url = git://git.savannah.gnu.org/gnulib.git;
  rev = "0fe2cbf6bb3dcf60a7c4004c332f9ef6ea855290";
  sha256 = "e401eab0dbff4493aeec75ad2af0582e646389d6454cc8be875469d0fe9aa955";
}

