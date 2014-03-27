/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009, 2010, 2011, 2012, 2013, 2014  Ludovic Courtès <ludo@gnu.org>
   Copyright (C) 2009  Rob Vermaas <rob.vermaas@gmail.com>

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
  meta = {
    description = "GNU Guile 2.0, an embeddable Scheme implementation";

    longDescription = ''
      GNU Guile is an implementation of the Scheme programming language, with
      support for many SRFIs, packaged for use in a wide variety of
      environments.  In addition to implementing the R5RS Scheme standard,
      Guile includes a module system, full access to POSIX system calls,
      networking support, multiple threads, dynamic linking, a foreign
      function call interface, and powerful string processing.
    '';

    homepage = http://www.gnu.org/software/guile/;
    license = "LGPLv3+";

    # Those who will receive email notifications.
    maintainers = [ "guile-commits@gnu.org" ];
  };

  # Systems we want to build for.
  systems = [ "x86_64-linux" "i686-linux" "x86_64-freebsd"
              "x86_64-darwin" "i686-sunos" ];

  nixpkgs = <nixpkgs>;
  pkgs = import nixpkgs {};
  crossSystems = (import ../cross-systems.nix) { inherit pkgs; };

  buildInputsFrom = pkgs: with pkgs; [
    readline libtool gmp gawk makeWrapper
    libunistring pkgconfig boehmgc libffi
  ];

  buildOutOfSourceTree = true;
  succeedOnFailure = true;
  keepBuildDirectory = true;

  /* Return the default configuration flags.  */
  defaultConfigureFlags = pkgs:
     with pkgs;

     ([ "--disable-silent-rules" ]

      # Explicitly link against libgcc_s, to work around the infamous
      # "libgcc_s.so.1 must be installed for pthread_cancel to work".
      # Note that `libgcc_s' is not found on Darwin (and not needed?).
      ++ (stdenv.lib.optional stdenv.isLinux [ "LDFLAGS=-lgcc_s" ])

     # FIXME: Commented because of:
     # libunistring-0.9.3/include/unistr.h:197:7: error: "CONFIG_UNICODE_SAFETY" is not defined
     #++ (stdenv.lib.optional stdenv.isLinux "--enable-error-on-warning")

     # The `--with' flags below aren't strictly needed, except on Cygwin
     # where the added `-L' linker flags help Libtool find the dlls, which in
     # turn allows it to produce dlls.
     ++ [ "--with-libreadline-prefix=${readline}"
          "--with-libunistring-prefix=${libunistring}"
          "--with-libgmp-prefix=${gmp}"
        ]
     ++ (stdenv.lib.optional (! (stdenv ? glibc))
        "--with-libiconv-prefix=${libiconv}")

     # Many shared libraries are missing on Cygwin, which prevents libtool
     # from actually building the shared libguile.  So explicitly disable
     # shared libraries so that tests relying on them are skipped.
     ++ (stdenv.lib.optional stdenv.isCygwin "--disable-shared")

     # Apple's GCC often ICEs when building `vm-engine.c'.  Hopefully `-O1'
     # does not stress it enough to crash.
     ++ (stdenv.lib.optional stdenv.isDarwin "CFLAGS=-O1"));

  /* Return a name/value attribute set where the value is a function suitable
     as a Hydra build function.  */
  makeBuild = configureFlags:
    let
      shortFlags = with builtins;
        (map (flag:
               if (substring 0 2 flag == "--")
               then substring 2 (stringLength flag) flag
               else flag)
             configureFlags);
      name = pkgs.lib.concatStringsSep "-" ([ "guile" ] ++ shortFlags);
      attrName = pkgs.lib.replaceChars ["-"] ["_"]
        (pkgs.lib.concatStringsSep "-" ([ "build" ] ++ shortFlags));
    in
      pkgs.lib.nameValuePair
        (builtins.trace ("build attribute `" + attrName
                         + "', derivation `" + name + "'")
                        attrName)

        (# Build the exotic configurations only on GNU/Linux.
         let pkgs = import nixpkgs { system = "x86_64-linux"; };
         in
           with pkgs;
           releaseTools.nixBuild {
             inherit name;
             src = jobs.tarball;
             configureFlags =
               (defaultConfigureFlags pkgs) ++ configureFlags;
             buildInputs = buildInputsFrom pkgs;
             meta = meta // { schedulingPriority = "50"; }; # lower priority
             inherit buildOutOfSourceTree
               succeedOnFailure keepBuildDirectory;
           });

  /* The exotic configurations under test.  */
  configurationSpace =
    [ [ "--disable-deprecated" "--disable-discouraged" ]
      [ "--disable-networking" ]
      [ "--enable-guile-debug" ]
      [ "CPPFLAGS=-DSCM_DEBUG=1" ]
      [ "CPPFLAGS=-DSCM_DEBUG_TYPING_STRICTNESS=2" ]
    ];

  makeCrossBuild = from: to: configureFlags:
    { native_guile ? (builtins.getAttr from jobs.build) # a native Guile build
    }:

    let
      crosspkgs = import nixpkgs { system = from; crossSystem = to; };

      # XXX: Temporarily use an old libgc know to work on GNU/Hurd.
      libgc = import ./old-libgc.nix { inherit (crosspkgs) fetchurl stdenv; };
    in
      (crosspkgs.releaseTools.nixBuild {
        name = "guile";
        src = jobs.tarball;
        preConfigure = "export GUILE_FOR_BUILD=${native_guile}/bin/guile";

        configureFlags =
          # Trick to have -I...-libunistring/include in CPPFLAGS.
          [ "--with-libunistring-prefix=${crosspkgs.libunistring.crossDrv}" ] ++
          (configureFlags crosspkgs);

        makeFlags = [ "V=1" ];

        nativeBuildInputs =
          [ native_guile crosspkgs.gawk crosspkgs.makeWrapper ];

        buildInputs = [ libgc ] ++
          (with crosspkgs; [ libtool gmp libunistring pkgconfig libffi ])

          # XXX: ncurses fails to build on MinGW.
          ++ (crosspkgs.stdenv.lib.optional (to != crossSystems.i686_pc_mingw32)
                crosspkgs.readline)

          # Try building with pthread support on MinGW.
          ++ (crosspkgs.stdenv.lib.optional (to == crossSystems.i686_pc_mingw32)
                crosspkgs.windows.pthreads);

        doCheck = false;
        meta = meta // { schedulingPriority = "50"; };
        inherit buildOutOfSourceTree succeedOnFailure keepBuildDirectory;
      }).crossDrv;

  jobs = rec {

    tarball =
      with pkgs;

      pkgs.releaseTools.sourceTarball {
        name = "guile-tarball";
        src = <guile>;
        buildInputs = [
          automake113x autoconf
          flex
          gettext_0_17
          git
          gnum4  # this should be a propagated build input of Autotools
          texinfo
          xz
          gperf                            # for Gnulib's iconv-related stuff
          (texLiveAggregationFun {
            paths = [ texLive texLiveCMSuper ];
          })
        ] ++ buildInputsFrom pkgs;

        # "make dist" needs to generate Texinfo files in `doc/ref' using the
        # just-built guile.
        dontBuild = false;

        preAutoconf =
          # Add a Git descriptor in the version number and tell Automake not
          # to check whether `NEWS' is up to date wrt. the version number.
          # The assumption is that `nix-prefetch-git' left the `.git'
          # directory in there.
          '' if [ ! -f build-aux/git-version-gen ]
             then
                 # Do it the old way for 1.8.
                 version_string="$((git describe || echo git) | sed -es/release_//g | tr - .)"
                 sed -i "GUILE-VERSION" \
                     -es"/^\(GUILE_VERSION=\).*$/\1$version_string/g"

                 sed -i "configure.in" -es"/check-news//g"
                 patch -p1 --batch < ${./disable-version-test.patch}
             fi

             ulimit -c unlimited
          '';

        configureFlags = [ "--disable-silent-rules" ];

        buildPhase =
          '' make

             # Arrange so that we don't end up, with profiling builds, with a
             # file named `<stdout>.gcov' since that confuses lcov.
             sed -i "libguile/c-tokenize.c" \
                 -e's/"<stdout>"/"c-tokenize.c"/g'
          '';

        postDist =
          # Tell Hydra about our manual.
          '' make -C doc/ref guile.pdf guile.html
             cp -rv doc/ref/guile.{pdf,html} "$out"
             ( echo "doc-pdf manual $out/guile.pdf" ;         \
               echo "doc manual $out/guile.html index.html" ) \
               >> $out/nix-support/hydra-build-products
          '';

        inherit succeedOnFailure keepBuildDirectory;
        meta = meta // { schedulingPriority = "220"; };
      };

    coverage =
      with pkgs;

      releaseTools.coverageAnalysis {
        name = "guile-coverage";
        src = jobs.tarball;
        buildInputs = buildInputsFrom pkgs;

        patchPhase =
          '' if [ ! -d module ]
             then
               # Patch for 1.8.
               patch -p1 <  "${nixpkgs}/pkgs/development/interpreters/guile/disable-gc-sensitive-tests.patch"
             fi
          '';

        checkPhase =
          '' make check || \
               echo "Tests failed, but continuing anyway."

             echo "running Scheme code coverage analysis, be patient..."
             stdbuf -o 0 -e 0 ./check-guile --coverage || \
               echo "Tests failed, but ignoring the problem."

             # Publish the raw LCOV info file, for debugging purposes.
             cp -v guile.info "$out/"
             echo "report lcov-scheme $out/guile.info" >> $out/nix-support/hydra-build-products
          '';
        lcovExtraTraceFiles = [ "guile.info" ];

        inherit succeedOnFailure keepBuildDirectory;

        meta = meta // {
          # On my 2.6 GHz laptop, it takes 136mn to run.
          maxSilent = 18000;
          schedulingPriority = 20;
        };
      };

    # The default build, executed on all platforms.
    build =
      pkgs.lib.genAttrs systems (system:

      let pkgs = import nixpkgs { inherit system; };
      in
        with pkgs;
        releaseTools.nixBuild {
          name = "guile";
          src = jobs.tarball;
          configureFlags = defaultConfigureFlags pkgs;
          buildInputs = buildInputsFrom pkgs;

          buildOutOfSourceTree =
            # On FreeBSD and OpenIndiana, the `.texi.info' rule under
            # `doc/ref' is triggered, which attempts to rebuild `guile.info'
            # under $srcdir, which fails when that location is not writable.
            # Not sure why (clock skew?), but let's avoid it.
            if stdenv.isFreeBSD || stdenv.isSunOS
            then false
            else buildOutOfSourceTree;

          inherit succeedOnFailure keepBuildDirectory;
          meta = meta // { schedulingPriority = "150"; };
        });

    # Building without pthread support.  Do this for all values of SYSTEM,
    # because pthread support tends to be buggy, so `--without-thread' builds
    # allows us to see what's wrong aside from pthread support.
    build_without_threads =
      pkgs.lib.genAttrs systems (system:

      let
        build = builtins.getAttr system jobs.build;
      in
        pkgs.lib.overrideDerivation build (attrs: {
          name = "guile-without-threads";
          configureFlags = attrs.configureFlags ++ [ "--without-threads" ];
        }));

    # Building with Clang.
    build_clang =
      pkgs.lib.genAttrs [ "x86_64-linux" "i686-linux" ] (system:

      let
        pkgs = import nixpkgs { inherit system; };
        build = builtins.getAttr system jobs.build;
      in
        (pkgs.lib.overrideDerivation build (attrs: {
          name = "guile-clang";
          preUnpack = "clang --version";
          buildInputs = attrs.buildInputs ++ [ pkgs.clang ];
          CC = "${pkgs.clang}/bin/clang";
        })
        //
        { meta = meta // { schedulingPriority = 20; }; }));

    # Check what it's like to build with another C compiler
    /* build_tinycc =
      { tarball ? jobs.tarball {}
      }:

      let
        system = "x86_64-linux";
        pkgs = import nixpkgs { inherit system; };
      in
        with pkgs;
        releaseTools.nixBuild {
          name = "guile";
          src = tarball;
          configureFlags =
            [ "CC=${tinycc}/bin/tcc" ] ++ (defaultConfigureFlags pkgs) ++
            [ "--with-libltdl-prefix=${libtool}"
              "--with-libgmp-prefix=${gmp}"
              "--with-libunistring-prefix=${libunistring}"
              "--with-readline-prefix=${readline}"
              "--disable-rpath"  # tcc doesn't support the `-rpath' option
            ];
          makeFlags = [ "V=1" ];
          buildInputs = buildInputsFrom pkgs;
          inherit meta buildOutOfSourceTree succeedOnFailure keepBuildDirectory;
        };
     */


    # XXX: Temporarily disabled since GNU Hurd is broken in Nixpkgs.
    # xbuild_gnu =
    #   # Cross build to GNU.
    #   makeCrossBuild "x86_64-linux" crossSystems.i586_pc_gnu
    #     (xpkgs:
    #        # On GNU, libgc depends on libpthread, but the cross linker doesn't
    #        # know where to find libpthread, which leads to erroneous test failures
    #        # in `configure', where `-pthread' and `-lpthread' aren't explicitly
    #        # passed.  So it needs some help (XXX).
    #        [ "LDFLAGS=-Wl,-rpath-link=${xpkgs.gnu.libpthreadCross}/lib" ]);

    # XXX: Temporarily disabled since MinGW is broken in Nixpkgs.
    # xbuild_mingw =
    #   # Cross build to MinGW.
    #   makeCrossBuild "i686-linux" crossSystems.i686_pc_mingw32
    #     (xpkgs:
    #        # `AI_ALL' & co. are missing on MinGW, so `net_db.c' won't build.
    #        [ "--disable-networking"
    #          "--with-libiconv-prefix=${xpkgs.libiconv.crossDrv}"
    #        ]);

    xbuild_mipsel_linux_gnu =
      # Cross build to `mipsel-linux-gnu' (Ben Nanonote).
      makeCrossBuild "x86_64-linux" crossSystems.mipsel_nanonote_linux_gnu
        (xpkgs: [ ]);

    xbuild_mips_linux_gnu =
      # Cross build to `mips-linux-gnu' (big endian).
      makeCrossBuild "x86_64-linux"
        (crossSystems.mipsel_nanonote_linux_gnu
         //
         {
           bigEndian = true;
           config = "mips-unknown-linux-gnu";
           float = "hard";
         })
        (xpkgs: [ ]);
  }

  //

  (builtins.listToAttrs (builtins.map makeBuild configurationSpace));

in jobs
