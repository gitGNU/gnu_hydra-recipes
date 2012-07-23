{ stdenv, fetchurl, gmp}:

stdenv.mkDerivation (rec {
  name = "mpfr-3.0.0";

  src = fetchurl {
    url = "mirror://gnu/mpfr/${name}.tar.bz2";
    sha256 = "0x8f4e5f9c53536cb798a30455ac429b1f9fc75a0f8af32d6e0ac31ebf1024821f";
  };

  buildInputs = [ gmp ];

  enableParallelBuilding = true;
  doCheck = true;

  meta = {
    homepage = http://www.mpfr.org/;
    description = "GNU MPFR, a library for multiple-precision floating-point arithmetic";

    longDescription = ''
      The GNU MPFR library is a C library for multiple-precision
      floating-point computations with correct rounding.  MPFR is
      based on the GMP multiple-precision library.

      The main goal of MPFR is to provide a library for
      multiple-precision floating-point computation which is both
      efficient and has a well-defined semantics.  It copies the good
      ideas from the ANSI/IEEE-754 standard for double-precision
      floating-point arithmetic (53-bit mantissa).
    '';

    license = "LGPLv3+";
  };
}

//

(stdenv.lib.optionalAttrs stdenv.isSunOS {
   CPPFLAGS = "-I${gmp}/include";
   LDFLAGS = "-L${gmp}/lib";
}))
