/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009, 2010, 2011, 2012  Ludovic Courtès <ludo@gnu.org>
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

{ nixpkgs ? <nixpkgs> }:

let
  meta = {
    description = "GNU Inetutils, a collection of common network programs";

    longDescription = ''
      GNU Inetutils is a collection of common network programs,
      including telnet, FTP, RSH, rlogin and TFTP clients and servers,
      among others.
    '';

    homepage = http://www.gnu.org/software/inetutils/;
    license = "GPLv3+";

    # Email notifications are sent to maintainers.
    maintainers = [ "build-inetutils@gnu.org" "ludo@gnu.org" ];
  };

  # Work around `AM_SILENT_RULES'.
  preBuild = "export V=99";

  pkgs = import nixpkgs {};
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs;
    [ readline ncurses shishi ] ++

    # Ironically, net-tools is needed to run the tests, which expect
    # `netstat'.
    (lib.optional stdenv.isLinux nettools);

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = rec {

    tarball =
      { inetutilsSrc ? { outPath = <inetutils>; }
      , gnulibSrc ? { outPath = <gnulib>; }
      }:

      releaseTools.sourceTarball {

	name = "inetutils-tarball";
	src = inetutilsSrc;

        # "make dist" alone won't work, so run "make" before.
        # http://lists.gnu.org/archive/html/bug-inetutils/2010-01/msg00004.html
        dontBuild = false;

        doCheck = false;

        configureFlags =
          [ "--with-ncurses-include-dir=${pkgs.ncurses}/include"
            "--with-shishi=${pkgs.shishi}"
          ];

        autoconfPhase = ''
          cp -Rv "${gnulibSrc}" ../gnulib
          chmod -R 755 ../gnulib

          ./bootstrap --gnulib-srcdir=../gnulib --copy
        '';

	buildInputs = (buildInputsFrom pkgs)
          ++ (with pkgs;
              [ autoconf automake111x bison perl git
                texinfo help2man gnum4
              ]);

        inherit preBuild meta succeedOnFailure keepBuildDirectory;
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "inetutils";
          src = tarball;
          VERBOSE = 1;
          buildInputs = (with pkgs; [ readline ncurses ]
            ++ (lib.optionals stdenv.isLinux [ nettools procps ]));
          configureFlags =
            [ "--with-ncurses-include-dir=${pkgs.ncurses}/include" ];
          inherit preBuild meta succeedOnFailure keepBuildDirectory;

          preConfigure =
            if pkgs.stdenv.isLinux
            then
              ''
                export PATH=$PATH:${pkgs.nettools}/sbin
                export USER=`${pkgs.coreutils}/bin/whoami`
              ''
            else "";

          # needed because make check need /etc/protocols
          __noChroot=true; 
        };

    build_shishi =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "inetutils";
          src = tarball;
          buildInputs = buildInputsFrom pkgs;
          configureFlags =
            [ "--with-ncurses-include-dir=${pkgs.ncurses}/include"
              "--with-shishi=${pkgs.shishi}"
            ];
          inherit preBuild meta;
        };

    xbuild_gnu =
      # Cross build to GNU.
      { tarball ? jobs.tarball {}
      }:

      let pkgs = import nixpkgs {
            crossSystem = crossSystems.i586_pc_gnu;
          };
      in
        (pkgs.releaseTools.nixBuild {
          name = "inetutils" ;
          src = tarball;
          buildInputs = with pkgs; [ ncurses readline ];
          configureFlags =
            [ "--with-ncurses-include-dir=${pkgs.ncurses}/include" ];
          doCheck = false;
        }).hostDrv;

    coverage =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.coverageAnalysis {
	name = "inetutils-coverage";
	src = tarball;
	buildInputs = buildInputsFrom pkgs;
        configureFlags =
          [ "--with-ncurses-include-dir=${pkgs.ncurses}/include"
            "--with-shishi=${pkgs.shishi}"
          ];
        inherit preBuild meta;
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      releaseTools.nixBuild {
        name = "inetutils-manual";
        src = tarball;
        buildInputs = (buildInputsFrom pkgs)
          ++ [ pkgs.texinfo pkgs.texLive ];

        buildPhase = "make -C doc html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/inetutils/inetutils.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/inetutils/inetutils.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        inherit preBuild meta;
      };
  };

in jobs
