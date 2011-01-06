/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009, 2010  Ludovic Courtès <ludo@gnu.org>

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

{ nixpkgs ? ../../nixpkgs }:

let
  pkgs = import nixpkgs {};
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  texLive = pkgs.texLiveAggregationFun { paths = [ pkgs.texLive pkgs.texLiveCMSuper ]; } ;

  preCheck =
    # Avoid interference from the ld wrapper.
    '' export NIX_DONT_SET_RPATH=1
       unset NIX_LD_WRAPPER_EXEC_HOOK

       unset NIX_CFLAGS_COMPILE
       unset NIX_CFLAGS_LINK
       unset NIX_LDFLAGS_BEFORE
       unset NIX_LDFLAGS
       unset NIX_LDFLAGS_AFTER
       unset NIX_GCC_WRAPPER_FLAGS_SET

       unset NIX_CROSS_CFLAGS_COMPILE
       unset NIX_CROSS_CFLAGS_LINK
       unset NIX_CROSS_LDFLAGS_BEFORE
       unset NIX_CROSS_LDFLAGS
       unset NIX_CROSS_LDFLAGS_AFTER
    '';

  inherit (pkgs) releaseTools;

  succeedOnFailure = true;
  keepBuildDirectory = true;

  jobs = rec {

    tarball =
      { libtoolSrc ? { outPath = /data/src/libtool; }
      , autoconf ? pkgs.autoconf
      , automake ? pkgs.automake111x
      }:

      releaseTools.sourceTarball {
	name = "libtool-tarball";
	src = libtoolSrc;
        bootstrapBuildInputs = [ autoconf automake ];
	buildInputs = with pkgs; [ git texinfo help2man lzma ];

        # help2man wants to run `libtoolize --help'.
        dontBuild = false;

        preConfigurePhases = "preAutoconfPhase autoconfPhase";
        preAutoconfPhase =
          '' echo "checking whether the environment is sane for bootstrap..."
             ( IFS=:
               for i in $ACLOCAL_PATH
               do
                 if find "$i" -name libtool\*m4
                 then
                     echo "found libtool m4 file in \`$i', stopping" >&2
                     exit 1
                 fi
               done ) || exit 1
             echo "environment looks good"
          '';
          inherit succeedOnFailure keepBuildDirectory;
          
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , autoconf ? pkgs.autoconf
      , automake ? pkgs.automake
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "libtool";
          src = tarball;
          buildInputs = [ autoconf automake ];
          inherit preCheck failureHook;
        };

    xbuild_gnu =
      # Cross build to GNU.
      { tarball ? jobs.tarball {}
      , autoconf ? pkgs.autoconf
      , automake ? pkgs.automake
      }:

      let pkgs = import nixpkgs {
            crossSystem = crossSystems.i586_pc_gnu;
          };
      in
      (pkgs.releaseTools.nixBuild {
	name = "libtool" ;
	src = tarball;
        buildNativeInputs = [ autoconf automake ];

        # The test suite can run in cross-compilation mode.
        doCheck = true;

        inherit preCheck succeedOnFailure keepBuildDirectory;

      }).hostDrv;

    manual =
      { tarball ? jobs.tarball {}
      , autoconf ? pkgs.autoconf
      , automake ? pkgs.automake
      }:

      releaseTools.nixBuild {
        name = "libtool-manual";
        src = tarball;
        buildInputs =
          [ autoconf automake pkgs.texinfo texLive
          ];

        buildPhase = "make html pdf";
        doCheck = false;
        installPhase =
          '' make install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/libtool/libtool.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/libtool/libtool.pdf" >> "$out/nix-support/hydra-build-products"
          '';
      };
  };

in jobs
