/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2013  Rob Vermaas <rob.vermaas@gmail.com>

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
, smalltalk ? { outPath = <smalltalk>; }
}:

let
  pkgs = import nixpkgs {};
  meta = {
    description = "GNU Smalltalk is a free implementation of the Smalltalk-80 language.";
    homepage = http://smalltalk.gnu.org/;
  };
  libsigsegv_patched = pkgs.lib.overrideDerivation pkgs.libsigsegv (args: { NIX_CFLAGS_COMPILE = "-fPIC"; });
  buildInputs = pkgs: with pkgs; [ zip unzip libffi libsigsegv_patched libtool];
in
  import ../gnu-jobs.nix {
    name = "smalltalk";
    src  = smalltalk;
    inherit nixpkgs meta;
    enableGnuCrossBuild = true;

    customEnv = {
      tarball = pkgs: {
        autoconfPhase = ''
          patchShebangs build-aux
          sed -i 's|GST_HAVE_LIB(libffi|GST_HAVE_LIB(ffi|' configure.ac
          autoreconf -vi
        '';
        buildInputs = with pkgs; [
          bison
          flex
          gettext_0_18
          git
          gperf
          help2man
          perl
          texinfo
          wget
        ] ++ (buildInputs pkgs);
        dontBuild = false;
      };

      build = pkgs: {
        buildInputs = buildInputs pkgs;
      };
    };
  }
