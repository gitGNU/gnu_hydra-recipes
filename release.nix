/* Builds of variants of the GNU System using the latest GNU packages
   straight from their repository.  */

{
/* Source trees of NixOS and Nixpkgs.  */
  nixos ? { outPath = ../nixos; rev = 0; }
, nixpkgs ? { outPath = ../nixpkgs; rev = 0; }

/* Source tarballs of the latest GNU packages.  */
, cpio ? { outPath = ./cpio-2.10.91.tar.bz2; }
, tar ? null }:

let
  latestGNUPackages = origPkgs: {
    cpio = origPkgs.lib.overrideDerivation origPkgs.cpio (origAttrs: {
      src = cpio;
      patches = [];
    });

    /* Stuff in stdenv...

    gnutar = pkgs.lib.overrideDerivation origPkgs.gnutar (origAttrs: {
      src = tar;
      patches = [];
    });

    */
  };

  makeIso =
    { module, description, maintainers ? [ "ludo@gnu.org" ]}:
    { system ? "i686-linux" }:

    let
      version = "0.0-pre${toString nixos.rev}";
      versionModule = { system.nixosVersion = version; };

      config = (import "${nixos}/lib/eval-config.nix" {
	inherit system nixpkgs;
	modules = [ module versionModule ];
      }).config // { packageOverrides = latestGNUPackages; };
      pkgs = import nixpkgs {};

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
      module = "${nixos}/modules/installer/cd-dvd/installation-cd-minimal.nix";
      description = "minimal";
    };
  }
