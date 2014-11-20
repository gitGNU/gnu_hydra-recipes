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

{ nixpkgs ? <nixpkgs>
, grep ? { outPath = <grep>; }
}:

let
  meta = {
    homepage = http://www.gnu.org/software/grep/;
    description = "GNU implementation of the Unix grep command";

    longDescription = ''
      The grep command searches one or more input files for lines
      containing a match to a specified pattern.  By default, grep
      prints the matching lines.
    '';

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers = [
      "Jim Meyering <jim@meyering.net>"
      "Rob Vermaas <rob.vermaas@gmail.com>"
    ];
  };
in
  import ../gnu-jobs.nix {
    name = "grep";
    src  = grep;
    inherit nixpkgs meta;

    systems = ["i686-linux" "x86_64-darwin" "x86_64-linux"];

    customEnv = {

      tarball = pkgs: {
        dontBuild = false;
        buildInputs = with pkgs;
          [ automake111x pkgconfig texinfo gettext_0_18 git perl
            rsync xz cvs gperf
          ];
      };

      build = pkgs: (with pkgs; {
        buildInputs = (lib.optional (stdenv.system != "i686-cygwin") pcre)
          ++ (lib.optional stdenv.isDarwin libiconv)
          ++ [ xz ];
      } // pkgs.lib.optionalAttrs stdenv.isDarwin { LDFLAGS="-L${libiconv}/lib -liconv"; } );

      xbuild_gnu = pkgs: { nativeBuildInputs = [ pkgs.xz ]; };
    };
  }
