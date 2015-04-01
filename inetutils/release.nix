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

{ nixpkgs ? <nixpkgs>
, inetutilsSrc ? { outPath = <inetutils>; }
}:

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

  buildInputsFrom = pkgs: with pkgs;
    [ readline ncurses shishi ] ++

    # Ironically, net-tools is needed to run the tests, which expect
    # `netstat'.
    (lib.optional stdenv.isLinux nettools);

  configureFlagsFor = pkgs:
    [ "--with-ncurses-include-dir=${pkgs.ncurses}/include"
      "--with-shishi=${pkgs.shishi}"
    ];

  pkgs = import nixpkgs {};

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs =
    (import ../gnu-jobs.nix {
      name = "inetutils";
      src  = inetutilsSrc;
      inherit nixpkgs meta;

      systems = [ "i686-linux" "x86_64-linux" ];

      customEnv = {

        tarball = pkgs: {
          dontBuild = false;

          doCheck = false;

          configureFlags = configureFlagsFor pkgs;

          buildInputs = (buildInputsFrom pkgs)
            ++ (with pkgs;
                [ autoconf automake111x bison perl git
                  texinfo help2man gnum4
                ]);

          inherit meta;
        } ;

        build = pkgs: {
          configureFlags = configureFlagsFor pkgs;
          buildInputs = buildInputsFrom pkgs;

          inherit meta succeedOnFailure keepBuildDirectory;
        } ;

        coverage = pkgs: {
          configureFlags = configureFlagsFor pkgs;
          buildInputs = buildInputsFrom pkgs;

          inherit meta succeedOnFailure keepBuildDirectory;
        } ;
      };
    }) // {
      manual = pkgs.releaseTools.nixBuild {
        name = "inetutils-manual";
        src = jobs.tarball;
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
        inherit meta;
      };
    };

in jobs
