{ nixpkgs ? ../../nixpkgs
, nixos ? ../../nixos
, services ? ../../services
, system ? builtins.currentSystem
, gnuModule
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
      # Build a network of nodes that using `gnuModule', i.e., using the
      # latest GNU packages and a GNU configuration.
      nodes =
        let gnuify = name: configFunction:
              builtins.trace "node `${name}'"
              (args:
                let
                  c = (configFunction args);
                  r = if c ? require then c.require else [];
                in
                  c // { require = r ++ [ gnuModule ]; });
        in
          pkgs.lib.mapAttrs gnuify nodes;
    };

    test = runTests vms t.testScript;
    report = makeReport test;
  };
in
  {
    version = apply (import ./version.nix);
  }
