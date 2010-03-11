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
      pkgs = import nixpkgs { inherit system; };

      version = "0.0-pre${toString nixos.rev}";

      latestGNUPackages = origPkgs: {
        coreutils = origPkgs.lib.overrideDerivation origPkgs.coreutils (origAttrs: {
          src = coreutils;
          patches = [];
        });

        cpio = origPkgs.lib.overrideDerivation origPkgs.cpio (origAttrs: {
          src = cpio;
          patches = [];
        });

        gnutar = pkgs.lib.overrideDerivation origPkgs.gnutar (origAttrs: {
          src = tar;
          patches = [];
        });

        guile_1_9 = pkgs.lib.overrideDerivation origPkgs.gnutar (origAttrs: {
          src = guile;
          patches = [];
        });
      };

      gnuModule = {
        gnu = true;
        system.nixosVersion = version;
        nixpkgs.config.packageOverrides = latestGNUPackages;
        installer.basePackages = gnuSystemPackages pkgs;

        # Don't build the GRUB menu builder script, since we don't need it
        # here and it causes a cyclic dependency.
        boot.loader.grub.enable = pkgs.lib.mkOverride 0 {} false;
      };

      config = (import "${nixos}/lib/eval-config.nix" {
	inherit system nixpkgs;
	modules = [ "${nixos}/modules/${module}" gnuModule ];
      });

      iso = config.system.build.isoImage;

    in
      with pkgs;

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
