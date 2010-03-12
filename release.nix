/* Builds of variants of the GNU System using the latest GNU packages
   straight from their repository.  */

{ nixpkgs ? ../nixpkgs }:

let
  latestGNUPackageNames =
    # A mapping from the name of the attributes passed to the build job
    # (e.g., the `tar' attribute points to the latest tarball of GNU tar)
    # to the attribute corresponding to that package in Nixpkgs (e.g.,
    # `gnutar' in Nixpkgs is the attribute name for GNU tar build).
    [ [ "coreutils" "coreutils" ]
      [ "cpio"      "cpio" ]
      [ "tar"       "gnutar" ]
      [ "guile"     "guile_1_9" ]
    ];

  latestGNUPackages =
    # Return an attribute set that overrides `origPkgs' with the packages
    # listed in `latestGNUPackages'.  The tarballs for the latest GNU
    # packages are taken from the `gnuPackages' attribute set.
    gnuPackages: origPkgs:

    let
      lib = (import nixpkgs {}).lib;

      # `makeSourceTarball' puts tarballs in $out/tarballs, so look there.
      preUnpack =
        ''
          if test -d "$src/tarballs"; then
              src=$(ls -1 "$src/tarballs/"*.tar.bz2 "$src/tarballs/"*.tar.gz | sort | head -1)
          fi
        '';
    in
      with lib; with builtins;
      fold (pkg: latestPkgs:
             let
               pkgName = head pkg;
               attrName = head (tail pkg);
               origPkg = getAttr attrName origPkgs;
               latestPkgSrc = getAttr pkgName gnuPackages;
               pkgFullName = "${pkgName}-${latestPkgSrc.version}";
             in
               latestPkgs
               //
               (trace "overriding package `${pkgFullName}', attribute `${attrName}'..."
                  listToAttrs [ {
                    name = attrName;
                    value = origPkgs.lib.overrideDerivation origPkg (origAttrs: {
                      name = pkgFullName;
                      src = latestPkgSrc;
                      patches = [];
                      inherit preUnpack;
                    });
                  } ]))
           {}
           latestGNUPackageNames;

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
    , ... }@args:

    let
      version = "0.0-pre${toString nixos.rev}";

      gnuModule =
        { pkgs, ... }:
        {
          gnu = true;
          system.nixosVersion = version;
          nixpkgs.config.packageOverrides = latestGNUPackages args;
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

    tests =
      { nixos ? { outPath = ../nixos; rev = 0; } }:

      import ./tests {
        inherit nixpkgs nixos;
        services = "${nixos}/services";
        system = "i686-linux";
      };
  }
