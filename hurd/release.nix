{ nixpkgs ? ../../nixpkgs
, hurdSrc ? { outPath = /data/src/hurd/hurd; }
}:

let
  pkgs = import nixpkgs {};
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  meta = {
    description = "The GNU Hurd, GNU project's replacement for the Unix kernel";

    longDescription =
      '' The GNU Hurd is the GNU project's replacement for the Unix kernel.
         It is a collection of servers that run on the Mach microkernel to
         implement file systems, network protocols, file access control, and
         other features that are implemented by the Unix kernel or similar
         kernels (such as Linux).
      '';

    license = "GPLv2+";

    homepage = http://www.gnu.org/software/hurd/;

    maintainers = [ pkgs.stdenv.lib.maintainers.ludo ];
  };

  jobs = {
    tarball =
      # "make dist" should work even non-natively and even without a
      # cross-compiler.  Doing so allows us to catch errors such as shipping
      # MIG-generated or compiled files in the distribution.
      pkgs.releaseTools.sourceTarball {
        name = "hurd-tarball";
        src = hurdSrc;
        configureFlags = "--build=i586-pc-gnu";  # cheat
        patches =
          [ ./dist-pfinet.patch
            ./dist-mach-defpager.patch
            ./dist-console-client.patch
            ./dist-libthreads.patch
            ./dist-exec.patch
            ./dist-libcons.patch
            ./dist-serverboot.patch
            ./dist-daemons.patch
            ./dist-sutils.patch
            ./dist-include.patch
          ];
        postPatch =
          '' # `mach-defpager' depends on code from `serverboot', but the
             # latter is no longer included in "make dist" and no longer
             # built.  Thus copy useful code from there.  See also
             # `dist-mach-defpager.patch'.
             ( cd serverboot &&                                       \
               mv -v default_pager.c kalloc.c wiring.[ch] queue.h     \
                  ../mach-defpager )

             echo "removing \`-o root' from makefiles..."
             for mf in {utils,daemons}/Makefile
             do
               sed -i "$mf" -e's/-o root//g'
             done
          '';
        preDist =
          '' echo "adding missing \`ChangeLog' files (due to commit f91f5eb5)..."
             for i in *
             do
               if [ -d "$i" ] && [ ! -f "$i/ChangeLog" ]
               then
                   : > "$i/ChangeLog"
               fi
             done

             : > "fatfs/EXTENSIONS"
          '';
        buildNativeInputs = [ pkgs.machHeaders pkgs.mig pkgs.texinfo ];
        inherit meta;
      };

    # Cross build from GNU/Linux.
    xbuild =
      { tarball ? jobs.tarball }:

      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";               # build platform
          crossSystem = crossSystems.i586_pc_gnu; # host platform
        };
      in
        (pkgs.releaseTools.nixBuild {
          name = "hurd";
          src = tarball;
          propagatedBuildNativeInputs = [ pkgs.machHeaders ];
          buildNativeInputs = [ pkgs.mig ];
          inherit meta;
        }).hostDrv;

    # Complete cross bootstrap of GNU from GNU/Linux.
    xbootstrap =
      { tarball ? jobs.tarball {} }:

      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";               # build platform
          crossSystem = crossSystems.i586_pc_gnu; # host platform
        };

        override = pkgName: origPkg: latestPkg:
          # Override the `src' attribute of `origPkg' with `latestPkg'.
          pkgs.lib.overrideDerivation origPkg (origAttrs: {
            name = "${pkgName}-${latestPkg.version}";
            src = latestPkg;
            patches = [];
            preAutoconf = ":";

            # `makeSourceTarball' puts tarballs in $out/tarballs, so look there.
            preUnpack =
              ''
                if test -d "$src/tarballs"; then
                    src=$(ls -1 "$src/tarballs/"*.tar.bz2 "$src/tarballs/"*.tar.gz | sort | head -1)
                fi
              '';
          });

        pkgsOverridden =
          # Override the `src' attribute of the Hurd packages.
          # TODO: Handle `hurdLibpthreadCross', `machHeaders', etc. similarly.
          override "hurd" pkgs.hurdCross tarball;
      in
        pkgsOverridden.hurdCross;
   };
in
  jobs
