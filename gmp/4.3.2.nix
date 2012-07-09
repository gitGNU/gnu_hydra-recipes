{stdenv, fetchurl, m4, cxx ? true}:

stdenv.mkDerivation rec {
  name = "gmp-4.3.2";

  src = fetchurl {
    url = "mirror://gnu/gmp/${name}.tar.bz2";
    sha256 = "0x8prpqi9amfcmi7r4zrza609ai9529pjaq0h4aw51i867064qck";
  };

  buildNativeInputs = [m4];

  # Even though this isn't recommended, we use this hack because
  # `--enable-fat' fails to build.
  preConfigure = "rm -fv config.guess && ln -sv configfsf.guess config.guess";

  enableParallelBuilding = true;
  doCheck = true;

  meta = {
    description = "A free library for arbitrary precision arithmetic, operating on signed integers, rational numbers, and floating point numbers";
    homepage = http://gmplib.org/;
    license = "LGPL";
  };
}
