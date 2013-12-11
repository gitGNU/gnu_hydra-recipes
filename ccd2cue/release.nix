/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2013 Bruno Félix Rezende Ribeiro <oitofelix@gnu.org>

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

{ nixpkgs ? <nixpkgs>,
  ccd2cue ? <ccd2cue> }:

let
  meta = {

    description = "The GNU CCD sheet to CUE sheet converter";

    longDescription = ''
    GNU ccd2cue is a CCD sheet to CUE sheet converter.  It supports the
    full extent of CUE sheet format expressiveness, including mixed-mode
    discs and CD-Text meta-data.  It plays an important role for those who
    need to use optical disc data which is only available in the
    proprietary sheet format CCD, but don't want to surrender their
    freedom.  It fills an important gap in the free software world because
    before its conception it was impossible to use complex forms of
    optical disc data laid out by CCD sheets in a whole/holy free
    operating system.

    The GNU ccd2cue documentation is also intended to be a reference
    documentation for both sheet format specifications.  That way we can
    reverse engineer the secret CCD sheet proprietary format only once and
    then make the information available for developers in order to benefit
    all free software users that want their software to be interoperable.
    The CUE sheet format is not a secret, but with this package we take
    the opportunity to ensure that its specification is available under a
    free documentation license for the sake of the whole free software
    community.
    '';

    homepage = https://www.gnu.org/software/ccd2cue/;
    license = "GPLv3+";
    maintainers = [ "Bruno Félix Rezende Ribeiro <oitofelix@gnu.org>" ];
  };
in
  import ../gnu-jobs.nix {
    inherit nixpkgs meta;
    name = "ccd2cue";
    src  = ccd2cue;
    systems = ["i686-linux" "x86_64-linux"];
  }
