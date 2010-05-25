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
  url = git://git.sv.gnu.org/paxutils.git;
  rev = "23f513275379f6305acf65437a96db4bdcd67571";
  sha256 = "deb84be9c0e45492d7062afe5ee7ce52221bdfdaa0088b1a96b03e11ac621ee7";
}

