/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2012  Ludovic Courtès <ludo@gnu.org>
   Copyright (C) 2010  Rob Vermaas <rob.vermaas@gmail.com>

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

{ nixpkgs ? <nixpkgs> }:

let
  meta = {
    description = "GNU Octave, a high-level language for numerical computations";
    homepage = http://www.octave.org/;
    license = "GPLv3+";
    maintainers = [ "Mike Miller <mtmiller@ieee.org>" ];
  };

  pkgs = import nixpkgs {};

  buildInputsFrom = pkgs: with pkgs;
    [ gfortran readline ncurses perl qhull blas liblapack pcre pkgconfig
      gnuplot zlib ghostscript transfig xfig pstoedit hdf5 texinfo
      qrupdate suitesparse curl texLive fftw fftwSinglePrec
      bzip2 glpk graphicsmagick openjdk
    ]

    # Optional dependencies for building native graphics on Mesa platforms.
    ++ (lib.optionals (lib.elem stdenv.system lib.platforms.mesaPlatforms)
         [ fltk13 fontconfig freefont_ttf freetype mesa ]);

  succeedOnFailure = true;
  keepBuildDirectory = true;

  # Octave needs a working font configuration to build the manual and to
  # run the test suite.
  FONTCONFIG_FILE = pkgs.makeFontsConf {
    fontDirectories = [
      "${pkgs.freefont_ttf}/share/fonts/truetype"
    ];
  };

  jobs = rec {

    tarball =
      { octave ? { outPath = <octave>; }
      , gnulib ? { outPath = <gnulib>; }
      }:
      with pkgs;
      releaseTools.makeSourceTarball {
	name = "octave-tarball";
	src = octave;
	inherit meta succeedOnFailure keepBuildDirectory;
	dontBuild = false;

	autoconfPhase = ''
	  # Disable Automake's `check-news' so that "make dist" always works.
	  sed -i "configure.ac" -es/gnits/gnu/g

	  cp -Rv ${gnulib} ../gnulib
	  chmod -R 755 ../gnulib

	  ./bootstrap --gnulib-srcdir=../gnulib --skip-po --copy
	'';

        configureFlags =
          [ "--with-qhull-includedir=${qhull}/include"
            "--with-qhull-libdir=${qhull}/lib"
          ];

	buildInputs = [
	  flex2535 git gperf bison automake111x mercurial] ++ buildInputsFrom pkgs ;
      };

    build =
      { system ? "x86_64-linux"
      , tarball ? jobs.tarball {}
      }:
      let pkgs = import nixpkgs { inherit system;} ;
      in with pkgs;
      releaseTools.nixBuild {
	name = "octave" ;
	src = tarball;
	inherit meta succeedOnFailure keepBuildDirectory;
	buildInputs = buildInputsFrom pkgs;
      };

    coverage =
      { tarball ? jobs.tarball {} }:
      with pkgs;

      releaseTools.coverageAnalysis {
	name = "octave-coverage";
	src = tarball;
	inherit meta;
	buildInputs = buildInputsFrom pkgs;
      };

  };

in jobs
