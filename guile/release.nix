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
    readline 
    libtool 
    gmp 
    gawk 
    makeWrapper
    libunistring 
    pkgconfig 
    boehmgc
  ];

  /* Return a name/value attribute set where the value is a function suitable
     as a Hydra build function.  */
  makeBuild = configureFlags:
    let
      shortFlags = with builtins;
        (map (flag: substring 2 (stringLength flag) flag)
             configureFlags);
      name = pkgs.lib.concatStringsSep "-" ([ "guile" ] ++ shortFlags);
      attrName = pkgs.lib.replaceChars ["-"] ["_"]
        (pkgs.lib.concatStringsSep "-" ([ "build" ] ++ shortFlags));
    in
      pkgs.lib.nameValuePair
        (builtins.trace ("build attribute `" + attrName
                         + "', derivation `" + name + "'")
                        attrName)

        ({ tarball ? jobs.tarball {}
         , system ? "x86_64-linux"
         }:

         let pkgs = import nixpkgs { inherit system; };
         in
           with pkgs;
           releaseTools.nixBuild {
             inherit name meta;
             src = tarball;
             configureFlags =
               [ "--enable-error-on-warning" ] ++ configureFlags;
             buildInputs = buildInputsFrom pkgs;
           });

  /* The configuration space under test.  */
  configurationSpace =
    [ [] # the default build, no `configure' arguments
      [ "--without-threads" ]
      [ "--disable-deprecated" ]
      [ "--disable-deprecated" "--disable-discouraged" ]
      [ "--disable-networking" ]
      [ "--enable-guile-debug" ]
    ];

  jobs = rec {

    tarball =
      { guileSrc ? {outPath = ../../guile;}
      }:

      with pkgs;

      pkgs.releaseTools.makeSourceTarball {
        name = "guile-tarball";
        src = guileSrc;
        buildInputs = [
          automake
          autoconf
          flex2535
          gettext
          git
          gnum4  # this should be a propagated build input of Autotools
          texinfo
        ] ++ buildInputsFrom pkgs;

        # make dist fails without this, so for now do make, make dist..
        dontBuild = false;

        preAutoconf =
          # Add a Git descriptor in the version number and tell Automake not
          # to check whether `NEWS' is up to date wrt. the version number.
          # The assumption is that `nix-prefetch-git' left the `.git'
          # directory in there.
          '' version_string="$((git describe || echo git) | sed -es/release_//g | tr - .)"
             sed -i "GUILE-VERSION" \
                 -es"/^\(GUILE_VERSION=\).*$/\1$version_string/g"

             # In `branch_release-1-8' we still use the old name.
             if test -f "configure.ac"
             then
                 configure_ac="configure.ac"
             else
                 configure_ac="configure.in"
             fi
             sed -i "$configure_ac" -es"/check-news//g"
          '';
        patches = [ ./disable-version-test.patch ];

        buildPhase =
          '' make

             # Arrange so that we don't end up, with profiling builds, with a
             # file named `<stdout>.gcov' since that confuses lcov.
             sed -i "libguile/c-tokenize.c" \
                 -e's/"<stdout>"/"c-tokenize.c"/g'
          '';

        inherit meta;
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
        inherit meta;
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
        inherit meta;
      };
  }

  //

  (builtins.listToAttrs (builtins.map makeBuild configurationSpace));

in jobs
