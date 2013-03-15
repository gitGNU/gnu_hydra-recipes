/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009, 2010, 2011, 2012  Ludovic Courtès <ludo@gnu.org>
   Copyright (C) 2009, 2010  Rob Vermaas <rob.vermaas@gmail.com>

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

let
  nixpkgs = <nixpkgs>;

  meta = {
    homepage = http://www.gnu.org/software/coreutils/;
    description = "The basic file, shell and text manipulation utilities of the GNU operating system";

    longDescription = ''
      The GNU Core Utilities are the basic file, shell and text
      manipulation utilities of the GNU operating system.  These are
      the core utilities which are expected to exist on every
      operating system.
    '';

    license = "GPLv3+";

    # Those who will receive email notifications.
    maintainers =
      [ "Jim Meyering <jim@meyering.net>"
        "Pádraig Brady <P@draigBrady.com>"
        "Ludovic Courtès <ludo@gnu.org>"
      ];
  };

  pkgs = import nixpkgs {};
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  buildInputsFrom = pkgs:
    with pkgs; [ perl gmp xz ] ++ (stdenv.lib.optional stdenv.isLinux acl);

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = {

    tarball =
      pkgs.releaseTools.sourceTarball {
        name = "coreutils-tarball";
        src = <coreutils>;

        buildInputs = (with pkgs;
          [ automake111x bison gettext_0_18
            git gperf texinfo rsync cvs
          ]) ++ buildInputsFrom pkgs;

        dontBuild = false;

        autoconfPhase = ''
          git config submodule.gnulib.url "${<gnulib>}"

          # By default `bootstrap' tries to download `.po' files from the
          # net, which doesn't work in chroots.  Skip that for now and
          # provide an empty `LINGUAS' file.
          touch po/LINGUAS
          ./bootstrap --gnulib-srcdir="${<gnulib>}" --skip-po
        '';

        inherit meta succeedOnFailure keepBuildDirectory;
      };

    build =
      { system ? "x86_64-linux" }:

      let pkgs = import nixpkgs {inherit system;};
      in
      pkgs.releaseTools.nixBuild {
        name = "coreutils" ;
        src = jobs.tarball;
        buildInputs = buildInputsFrom pkgs ;
        configureFlags = let stdenv = pkgs.stdenv; in
          [ "--enable-install-program=arch,hostname" ]
          ++ (stdenv.lib.optional stdenv.isLinux [ "--enable-gcc-warnings" ]);
        inherit meta succeedOnFailure keepBuildDirectory;
      };

    xbuild_gnu =
      # Cross build to GNU.
      let pkgs = import nixpkgs {
            crossSystem = crossSystems.i586_pc_gnu;
          };
      in
      (pkgs.releaseTools.nixBuild {
        name = "coreutils" ;
        src = jobs.tarball;
        buildInputs = [ pkgs.gmp ];
        nativeBuildInputs = with pkgs; [ perl xz ];
        configureFlags = [ "--enable-install-program=arch,hostname" ];
        doCheck = false;
        inherit meta succeedOnFailure keepBuildDirectory;
      }).crossDrv;

    coverage =
      pkgs.releaseTools.coverageAnalysis {
        name = "coreutils-coverage";
        src = jobs.tarball;
        configureFlags = [ "--enable-install-program=arch,hostname" ];
        buildInputs = buildInputsFrom pkgs;
        postCheck =
          # Remove the file that confuses lcov.
          '' rm -fv 'src/<built-in>.'*
             rm -fv src/getlimits.gc*
          '';
        inherit meta;
      };

    manual =
      pkgs.releaseTools.nixBuild {
        name = "coreutils-manual";
        src = jobs.tarball;
        buildInputs = buildInputsFrom pkgs ++ [ pkgs.texinfo pkgs.texLive ];
        doCheck = false;

        buildPhase = "make html pdf";
        installPhase =
          '' make install-html-am install-pdf-am

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/coreutils/coreutils.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/coreutils/coreutils.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        inherit meta;
      };
  };

in jobs
