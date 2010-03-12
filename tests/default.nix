{ nixpkgs ? ../../nixpkgs
, nixos ? ../../nixos
, services ? ../../services
, system ? builtins.currentSystem
}:

with import "${nixos}/lib/testing.nix" { inherit nixpkgs services system; };

{
  # FIXME: Use the latest GNU packages.
  version = apply (import ./version.nix);
}
