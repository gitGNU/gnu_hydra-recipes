/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2009, 2010  Ludovic Courtès <ludo@gnu.org>
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

{nixpkgs ? ../../nixpkgs}:
let
  meta = {
    description = "GNU Guile 1.9, an embeddable Scheme implementation";

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

  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs; [
    readline libtool gmp gawk makeWrapper
    libunistring pkgconfig boehmgc libffi
  ];

  /* Return the default configuration flags.  */
  defaultConfigureFlags = pkgs:
     with pkgs;

     # FIXME: Temporarily commented out because of libunistring issues.
     # http://lists.gnu.org/archive/html/bug-gnulib/2010-05/msg00226.html
     (#(stdenv.lib.optional stdenv.isLinux "--enable-error-on-warning")
      []

     # The `--with' flags below aren't strictly needed, except on Cygwin
     # where the added `-L' linker flags help Libtool find the dlls, which in
     # turn allows it to produce dlls.
     ++ [ "--with-libreadline-prefix=${readline}"
          "--with-libunistring-prefix=${libunistring}"
          "--with-libgmp-prefix=${gmp}"
        ]
     ++ (stdenv.lib.optional (! (stdenv ? glibc))
        "--with-libiconv-prefix=${libiconv}"));

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

        ({ tarball ? jobs.tarball {} }:

         # Build the exotic configurations only on GNU/Linux.
         let pkgs = import nixpkgs { system = "x86_64-linux"; };
         in
           with pkgs;
           releaseTools.nixBuild {
             inherit name meta;
             src = tarball;
             configureFlags =
               (defaultConfigureFlags pkgs) ++ configureFlags;
             buildInputs = buildInputsFrom pkgs;
             buildOutOfSourceTree = true;
           });

  /* The exotic configurations under test.  */
  configurationSpace =
    [ [ "--without-threads" ]
      [ "--disable-deprecated" "--disable-discouraged" ]
      [ "--disable-networking" ]
      [ "--enable-guile-debug" ]
      [ "CPPFLAGS=-DSCM_DEBUG=1" ]
    ];

  failureHook =
    '' if [ -f check-guile.log ]
       then
           echo
           echo "build failed, dumping test log..."
           cat check-guile.log
       elif [ -f config.log -a ! -f Makefile ]
       then
           echo
           echo "configuration failed, dumping config.log..."
           cat config.log
       fi
    '';

  jobs = rec {

    tarball =
      { guileSrc ? {outPath = ../../guile;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "guile-tarball";
        src = guileSrc;
        buildInputs = [
          automake111x
          autoconf
          flex2535
          gettext_0_17
          git
          gnum4  # this should be a propagated build input of Autotools
          texinfo
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

        buildPhase =
          '' make

             # Arrange so that we don't end up, with profiling builds, with a
             # file named `<stdout>.gcov' since that confuses lcov.
             sed -i "libguile/c-tokenize.c" \
                 -e's/"<stdout>"/"c-tokenize.c"/g'
          '';

        inherit meta failureHook;
      };

    coverage =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.coverageAnalysis {
        name = "guile-coverage";
        src = tarball;
        buildInputs = buildInputsFrom pkgs;
        patches = [
          "${nixpkgs}/pkgs/development/interpreters/guile/disable-gc-sensitive-tests.patch" 
        ];

        postCheck =
          '' echo "running Scheme code coverage analysis, be patient..."
             rm -v "test-suite/tests/poe.test"  # for bug #29616
             stdbuf -o 0 -e 0 ./check-guile --coverage

             # Publish the raw LCOV info file.
             cp -v guile.info "$out/"
             echo "report lcov-scheme $out/guile.info" >> $out/nix-support/hydra-build-products
          '';
        lcovExtraTraceFiles = [ "guile.info" ];

        inherit failureHook;

        meta = meta // { schedulingPriority = "20"; };
      };

    manual =
      { tarball ? jobs.tarball {}
      }:

      with pkgs;

      releaseTools.nixBuild {
        name = "guile-manual";
        src = tarball;
        buildInputs = buildInputsFrom pkgs ++ [ pkgs.texinfo pkgs.texLive ];
        doCheck = false;

        buildPhase = "make -C doc/ref html pdf";
        installPhase =
          '' make -C doc/ref install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/guile/guile.html index.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/guile/guile.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        buildOutOfSourceTree = true;
        inherit meta failureHook;
      };

    # The default build, executed on all platforms.
    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        with pkgs;
        releaseTools.nixBuild {
          name = "guile";
          src = tarball;
          configureFlags = defaultConfigureFlags pkgs;
          buildInputs = buildInputsFrom pkgs;
          buildOutOfSourceTree = true;
          inherit meta failureHook;
        };

    # Check what it's like to build with an old compiler.
    build_gcc3 =
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
          configureFlags = defaultConfigureFlags pkgs;
          buildInputs = [ pkgs.gcc34 ] ++ (buildInputsFrom pkgs);
          buildOutOfSourceTree = true;
          preUnpack = "gcc --version";
          inherit meta failureHook;
        };

    # Check what it's like to build with an old compiler.
    build_tinycc =
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
          buildOutOfSourceTree = true;
          patches = [ ./tinycc-isnan.patch ];
          inherit meta failureHook;
        };
  }

  //

  (builtins.listToAttrs (builtins.map makeBuild configurationSpace));

in jobs
