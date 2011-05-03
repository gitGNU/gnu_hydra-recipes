/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010  Eelco Dolstra <e.dolstra@tudelft.nl>
   Copyright (C) 2010  Ludovic Courtès <ludo@gnu.org>
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

/* Builds of variants of the GNU System using the latest GNU packages
   straight from their repository.  */

{ nixpkgs ? ../nixpkgs

  /* Source tree of NixOS.  */
, nixos ? { outPath = ../nixos; rev = 0; }

  /* Source tarballs of the latest GNU packages.  */
#, glibc     ? (import glibc/release.nix {}).tarball {}
, coreutils ? (import coreutils/release.nix {}).tarball {}
, cpio      ? (import cpio/release.nix {}).tarball {}
, guile     ? (import guile/release.nix {}).tarball {}
, grep      ? (import grep/release.nix {}).tarball {}
, inetutils ? (import inetutils/release.nix {}).tarball {}
, tar       ? (import tar/release.nix {}).tarball {}
, patch     ? (import patch/release.nix {}).tarball {}
}:

let
  # Override GNU packages in `origPkgs' so that they use bleeding-edge
  # tarballs.
  latestGNUPackages = origPkgs:
    let
      override = pkgName: origPkg: latestPkg:
        origPkgs.lib.overrideDerivation origPkg (origAttrs: {
          name = "${pkgName}-${latestPkg.version}";
          src = latestPkg;
          patches = [];

          # `makeSourceTarball' puts tarballs in $out/tarballs, so look there.
          preUnpack =
            ''
              if test -d "$src/tarballs"; then
                  src=$(ls -1 "$src/tarballs/"*.tar.bz2 "$src/tarballs/"*.tar.gz | sort | head -1)
              fi
            '';
        });

#       glibcNew = glibc;
     in
       {
         /*
         # The bootstrap tools on x86_64 contain an old version of GNU as,
         # which doesn't support `gnu_indirect_function', leading to a build
         # failure when multi-arch support is enabled.  Thus, build with
         # `--disable-multi-arch'.
         glibc = origPkgs.lib.overrideDerivation origPkgs.glibc (origAttrs: {
           name = "glibc-${glibcNew.version}";
           src = glibcNew;
           # XXX: Could be useful to keep some of the Nixpkgs patches but
           # some of them no longer apply.
           patches = [];
           configureFlags = origPkgs.glibc.configureFlags ++ [ "--disable-multi-arch" ];
           preUnpack = '' src="$(echo $src/tarballs/*.bz2)" '';
         });
         */

         coreutils = override "coreutils" origPkgs.coreutils coreutils;
         cpio = override "cpio" origPkgs.cpio cpio;
         gnutar = override "tar" origPkgs.gnutar tar;
         gnugrep = override "grep" origPkgs.gnugrep grep;
         guile_1_9 = override "guile" origPkgs.guile_1_9 guile;
         inetutils = override "inetutils" origPkgs.inetutils inetutils;
         gnupatch = override "patch" origPkgs.gnupatch patch;
       };

  # List of base packages for the ISO.
  gnuSystemPackages = pkgs:
    [ pkgs.subversion # for nixos-checkout
      pkgs.w3m # needed for the manual
      pkgs.grub2
      pkgs.fdisk
      pkgs.parted
      pkgs.ddrescue
      pkgs.screen

      # Networking tools.
      pkgs.inetutils
      pkgs.lsh
      pkgs.netcat
      pkgs.wpa_supplicant # !!! should use the wpa module

      # Hardware-related tools.
      pkgs.sdparm
      pkgs.hdparm
      pkgs.dmraid

      # Compression tools.
      pkgs.xz

      # Editors.
      pkgs.emacs
      pkgs.zile

      # Debugging tools
      pkgs.gdb

      # Last but not least...
      pkgs.guile_1_9
    ];

  makeIso =
    { module, description, maintainers ? [ "ludo" ]}:
    { system ? "i686-linux" }:

    let
      version = "0.0-pre${toString nixos.rev}";

      gnuModule =
        { pkgs, ... }:
        {
          gnu = true;
          system.nixosVersion = version;
          nixpkgs.config.packageOverrides = latestGNUPackages;
          environment.systemPackages = gnuSystemPackages pkgs;

          # Don't build the GRUB menu builder script, since we don't need it
          # here and it causes a cyclic dependency.
          boot.loader.grub.enable = pkgs.lib.mkOverrideTemplate 0 {} false ;
        };

      c = (import "${nixos}/lib/eval-config.nix" {
        inherit system nixpkgs;
        modules = [ "${nixos}/modules/${module}" gnuModule ];
      });

      config = c.config;

      iso = config.system.build.isoImage;

    in
      with c.pkgs;

      # Declare the ISO as a build product so that it shows up in Hydra.
      runCommand "gnu-on-linux-iso-${version}"
	{ meta = {
	    description = "NixOS GNU/Linux installation CD (${description}) - ISO image for ${system}-gnu";
	    maintainers = map (x: lib.getAttr x lib.maintainers) maintainers;
            schedulingPriority = "10";
	  };
	  inherit iso;
	  passthru = { inherit config; };
	}
	''
	  ensureDir $out/nix-support
	  echo "file iso" "$iso/iso/"*.iso* >> "$out/nix-support/hydra-build-products"
	'';

in

  rec {
    iso_minimal = makeIso {
      module = "installer/cd-dvd/installation-cd-minimal.nix";
      description = "minimal";
    };

    tests =
      { system ? "x86_64-linux" }:

      let
        gnuConfigOptions =
          {
            gnu = true;
            nixpkgs.config.packageOverrides = latestGNUPackages;
          };

        testsuite = import ./tests {
             inherit nixpkgs nixos system gnuConfigOptions;
           };
      in {
        version = testsuite.version.test;

        # Selected NixOS tests.
        login = testsuite.login.test;
        portmap = testsuite.portmap.test;
      };
  }
