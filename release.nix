/* Builds of variants of the GNU System using the latest GNU packages
   straight from their repository.  */

{ nixpkgs ? ../nixpkgs }:

let
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

      # Last but not least...
      pkgs.guile_1_9
    ];

  makeIso =
    { module, description, maintainers ? [ "ludo" ]}:
    { system ? "i686-linux"

      /* Source tree of NixOS.  */
    , nixos ? { outPath = ../nixos; rev = 0; }

      /* Source tarballs of the latest GNU packages.  */
    , coreutils, cpio, tar, guile }:

    let
      version = "0.0-pre${toString nixos.rev}";

      # `makeSourceTarball' puts tarballs in $out/tarballs, so look there.
      preUnpack =
        ''
          if test -d "$src/tarballs"; then
              src=$(ls -1 "$src/tarballs/"*.tar.bz2 "$src/tarballs/"*.tar.gz | sort | head -1)
          fi
        '';

      latestGNUPackages = origPkgs: {
        coreutils = origPkgs.lib.overrideDerivation origPkgs.coreutils (origAttrs: {
          name = "coreutils-${coreutils.version}";
          src = coreutils;
          patches = [];
          inherit preUnpack;
        });

        cpio = origPkgs.lib.overrideDerivation origPkgs.cpio (origAttrs: {
          name = "cpio-${cpio.version}";
          src = cpio;
          patches = [];
          inherit preUnpack;
        });

        gnutar = origPkgs.lib.overrideDerivation origPkgs.gnutar (origAttrs: {
          name = "tar-${tar.version}";
          src = tar;
          patches = [];
          inherit preUnpack;
        });

        guile_1_9 = origPkgs.lib.overrideDerivation origPkgs.guile_1_9 (origAttrs: {
          name = "guile-${guile.version}";
          src = guile;
          patches = [];
          inherit preUnpack;
        });
      };

      gnuModule =
        { pkgs, ... }:
        {
          gnu = true;
          system.nixosVersion = version;
          nixpkgs.config.packageOverrides = latestGNUPackages;
          installer.basePackages = gnuSystemPackages pkgs;

          # Don't build the GRUB menu builder script, since we don't need it
          # here and it causes a cyclic dependency.
          boot.loader.grub.enable = pkgs.lib.mkOverride 0 {} false;
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
  }
