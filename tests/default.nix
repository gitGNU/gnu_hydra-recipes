/* Continuous integration of GNU with Hydra/Nix.
   Copyright (C) 2010  Ludovic Courtès <ludo@gnu.org>

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

{ nixpkgs ? ../../nixpkgs
, nixos ? ../../nixos
, services ? ../../services
, system ? builtins.currentSystem
, gnuConfigOptions
}:

with import "${nixos}/lib/testing.nix" { inherit nixpkgs services system; };
with import "${nixos}/lib/build-vms.nix" { inherit nixpkgs services system; };

let
  call = f: f { inherit nixpkgs system pkgs; };

  apply = testFun: complete (call testFun);

  complete = t: t // rec {
    nodes =
      if t ? nodes then t.nodes else
      if t ? machine then { machine = t.machine; }
      else { };
    vms = buildVirtualNetwork {
      # Build a network of nodes that use `gnuConfigOptions', i.e., the
      # latest GNU packages and a GNU configuration.
      nodes =
        let gnuify = name: configFunction:
              builtins.trace "node `${name}'"
              (args: (configFunction args) // gnuConfigOptions);
        in
          pkgs.lib.mapAttrs gnuify nodes;
    };

    test = runTests vms t.testScript;
    report = makeReport test;
  };
in
  {
    version = apply (import ./version.nix);

    # Selected NixOS tests.
    login = apply (import "${nixos}/tests/login.nix");
    portmap = apply (import "${nixos}/tests/portmap.nix");
  }
