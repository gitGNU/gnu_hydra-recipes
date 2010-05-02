{ nixpkgs    ? ../../nixpkgs
, gsaslSrc   ? { outPath = ../../gsasl; }
, libidn     ? (import ../libidn/release.nix {}).build {}
, libgcrypt  ? (import ../libgcrypt/release.nix {}).build {}
}:

let
  pkgs = import nixpkgs {};

  meta = {
    description = "GNU Simple Authentication and Security Layer (SASL) Library";

    longDescription = ''
       GNU SASL is an implementation of the Simple Authentication and
       Security Layer framework and a few common SASL mechanisms.
    '';

    homepage = http://www.gnu.org/software/gsasl/;
    license = "LGPLv2.1+";

    # Where notification emails go.
    maintainers =
      [ "gsasl-commit@gnu.org"
         pkgs.stdenv.lib.maintainers.ludo
      ];
  };

  inherit (pkgs) releaseTools;

  buildInputsFrom = pkgs: with pkgs;
    [ gettext pkgconfig perl gss ]
    ++ stdenv.lib.optional stdenv.isLinux valgrind;

  jobs = rec {

    tarball =
      releaseTools.sourceTarball {
	name = "gsasl-tarball";
	src = gsaslSrc;

        patches = [ ../libtasn1/interpreter-path.patch ];

        # `help2man' wants to run `src/gsasl'.
        dontBuild = false;

        doCheck = false;

        autoconfPhase = "make";
        configureFlags = "--enable-gtk-doc";
	buildInputs = (buildInputsFrom pkgs)
          ++ [ libgcrypt libidn ]
          ++ (with pkgs;
              [ autoconf automake111x gperf gengetopt git
                texinfo help2man
                cvs # for `autopoint'
                gnome.gtkdoc docbook_xsl
                libxml2 # for its setup-hook
                texinfo texLive
              ]);

        inherit meta;
      };

    build =
      { tarball ? jobs.tarball
      , system ? "x86_64-linux"
      }:

      let pkgs = import nixpkgs { inherit system; };
      in
        pkgs.releaseTools.nixBuild {
          name = "gsasl";
          src = tarball;
          configureFlags = "";
          buildInputs = (buildInputsFrom pkgs) ++ [ libgcrypt libidn ];
          inherit meta;
        };

    coverage =
      { tarball ? jobs.tarball
      }:

      releaseTools.coverageAnalysis {
	name = "gsasl-coverage";
	src = tarball;
        configureFlags = "";
        buildInputs = (buildInputsFrom pkgs) ++ [ libgcrypt libidn ];
        # No `meta' so that mail notifications are not sent.
      };

    manual =
      { tarball ? jobs.tarball
      }:

      releaseTools.nixBuild {
        name = "gsasl-manual";
        src = tarball;
        configureFlags = "";
        buildInputs = (buildInputsFrom pkgs)
          ++ [ libgcrypt libidn ]
          ++ [ pkgs.texinfo pkgs.texLive ];

        buildPhase = "make -C doc html pdf";
        doCheck = false;
        installPhase =
          '' make -C doc install-html install-pdf

             ensureDir "$out/nix-support"
             echo "doc manual $out/share/doc/gsasl/gsasl.html" >> "$out/nix-support/hydra-build-products"
             echo "doc-pdf manual $out/share/doc/gsasl/gsasl.pdf" >> "$out/nix-support/hydra-build-products"
          '';
        inherit meta;
      };
  };

in jobs
