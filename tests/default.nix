{ nixpkgs ? ../../nixpkgs
, nixos ? ../../nixos
, services ? ../../services
, system ? builtins.currentSystem
, gnuOverrides
}:

# FIXME: Somehow pass `gnuOverrides' to the testing framework.
with import "${nixos}/lib/testing.nix" { inherit nixpkgs services system; };

{
  version = apply (import ./version.nix);
}
