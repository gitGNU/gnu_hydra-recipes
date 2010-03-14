{ nixpkgs ? ../../nixpkgs
, nixos ? ../../nixos
, services ? ../../services
, system ? builtins.currentSystem
, gnuOverrides
}:

with import "${nixos}/lib/testing.nix" { inherit nixpkgs services system; };
with import "${nixos}/lib/build-vms.nix" { inherit nixpkgs services system; };

let
  call = f: f { inherit nixpkgs system; pkgs = gnuOverrides pkgs; };

  apply = testFun: complete (call testFun);

  complete = t: t // rec {
    nodes =
      if t ? nodes then t.nodes else
      if t ? machine then { machine = t.machine; }
      else { };
    vms = buildVirtualNetwork { inherit nodes; };
    test = runTests vms t.testScript;
    report = makeReport test;
  };
in
  {
    version = apply (import ./version.nix);
  }
