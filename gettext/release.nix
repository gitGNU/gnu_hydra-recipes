/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2012  Rob Vermaas <rob.vermaas@gmail.com>
   Copyright (C) 2012  Daiki Ueno <ueno@gnu.org>

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
, gettext ? { outPath = <gettext>; }
}:

let
  pkgs = import nixpkgs {};

  meta = {
    homepage = http://www.gnu.org/software/gettext/;

    description = "GNU gettext, a well integrated set of translation tools and documentation";

    longDescription = ''
      Usually, programs are written and documented in English, and use
      English at execution time for interacting with users.  Using a
      common language is quite handy for communication between
      developers, maintainers and users from all countries.  On the
      other hand, most people are less comfortable with English than
      with their own native language, and would rather be using their
      mother tongue for day to day's work, as far as possible.  Many
      would simply love seeing their computer screen showing a lot
      less of English, and far more of their own language.

      GNU `gettext' is an important step for the GNU Translation
      Project, as bit is an asset on which we may build many other
      steps. This package offers to programmers, translators, and even
      users, a well integrated set of tools and
      documentation. Specifically, the GNU `gettext' utilities are a
      set of tools that provides a framework to help other GNU
      packages produce multi-lingual messages.
    '';

    # some files are under GPLv2+ and LGPL
    license = "GPLv3";

    maintainers = [
      "Daiki Ueno <ueno@gnu.org>"
    ];
  };
in
  import ../gnu-jobs.nix {
    name = "gettext";
    src  = gettext;
    inherit nixpkgs meta;

    systems = ["x86_64-linux" "i686-linux" "x86_64-darwin"];

    customEnv = {
      tarball = pkgs: {
        patches = [
	  ./tar-should-not-expect-a-root-user.patch
	  ./tar-no-long-file-name.patch
	];
        dontBuild = false;
        autoconfPhase = ''
          # archive.dir.tar is not under version control; prepare an empty
          # tarball before building
          : > dummy
          tar cf gettext-tools/misc/archive.dir.tar dummy
          rm -f dummy
          # fetch gnulib from the local repository
          git config submodule.gnulib.url "${<gnulib>}"
          export GNULIB_SRCDIR="${<gnulib>}"
          ./autogen.sh
        '';
	preDist = ''
	  (cd gettext-tools/examples/po && make update-po)
	'';
        configureFlags =
          [ "--with-libcroco-0.6-prefix=${pkgs.libcroco}"
            "--with-libglib-2.0-prefix=${pkgs.glib}"
            "--with-libxml2-prefix=${pkgs.libxml2}"
            "--with-libunistring-prefix=${pkgs.libunistring}" ];
        buildInputs = with pkgs; [
          automake114x
          bison
          gettext_0_18 # needed for bootstrap
          git
          glib
          gperf
          groff
          help2man
          libcroco
          libunistring
          libxml2
          perl
          texinfo
          wget
        ];
      };

      build = pkgs: {
        buildInputs = with pkgs; lib.optional (!stdenv.isLinux) libiconv;
      };
    };
  }
