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
, system ? builtins.currentSystem
, gnuConfigOptions
}:

with import "${nixos}/lib/testing.nix" { inherit nixpkgs system; };
with import "${nixos}/lib/build-vms.nix" { inherit nixpkgs system; };
with pkgs;
let
  gnuify = name: configFunction:
              builtins.trace "node `${name}'"
              (args: (configFunction args) // gnuConfigOptions);

  call = f: f { inherit nixpkgs system pkgs; };

  apply = testFun: complete (call testFun);

  complete = t: t // rec {
    nodes = buildVirtualNetwork ( pkgs.lib.mapAttrs gnuify (
      if t ? nodes then t.nodes else
      if t ? machine then { machine = t.machine; }
      else { } ));

    testScript =
      # Call the test script with the computed nodes.
      if builtins.isFunction t.testScript
      then t.testScript { inherit nodes; }
      else t.testScript;

    vlans = map (m: m.config.virtualisation.vlans) (lib.attrValues nodes);

    vms = map (m: m.config.system.build.vm) (lib.attrValues nodes);

    # Generate onvenience wrappers for running the test driver
    # interactively with the specified network, and for starting the
    # VMs from the command line.
    driver = runCommand "nixos-test-driver"
      { buildInputs = [ makeWrapper];
        inherit testScript;
      }
      ''
        mkdir -p $out/bin
        echo "$testScript" > $out/test-script
        ln -s ${testDriver}/bin/nixos-test-driver $out/bin/
        vms="$(for i in ${toString vms}; do echo $i/bin/run-*-vm; done)"
        wrapProgram $out/bin/nixos-test-driver \
          --add-flags "$vms" \
          --run "testScript=\"\$(cat $out/test-script)\"" \
          --set testScript '"$testScript"' \
          --set VLANS '"${toString vlans}"'
        ln -s ${testDriver}/bin/nixos-test-driver $out/bin/nixos-run-vms
        wrapProgram $out/bin/nixos-run-vms \
          --add-flags "$vms" \
          --set tests '"startAll; sleep 1e9;"' \
          --set VLANS '"${toString vlans}"'
      ''; # "

    test = runTests driver;

    report = makeReport test;
  };

in
  {
    version = apply (import ./version.nix);

    # Selected NixOS tests.
    login = apply (import "${nixos}/tests/login.nix");
    portmap = apply (import "${nixos}/tests/portmap.nix");
  }
