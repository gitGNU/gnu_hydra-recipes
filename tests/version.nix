{ pkgs, gnuOverrides, ... }:

{
  machine = { config, pkgs, ... }: {
    gnu = true;

    # Extra packages wanted in the global environment.
    environment.systemPackages =
      [ pkgs.cpio pkgs.guile_1_9 pkgs.inetutils ];

    # Use the latest packages.
    nixpkgs.config.packageOverrides = gnuOverrides;
  };

  testScript =
    ''
      $machine->mustSucceed("ldd --version >&2");
      $machine->mustSucceed("touch --version >&2");
      $machine->mustSucceed("tar --version >&2");
      $machine->mustSucceed("cpio --version >&2");
      $machine->mustSucceed("ifconfig --version >&2");
      $machine->mustSucceed("guile --version >&2");
      $machine->mustSucceed("guile -c '(format #t \"hello, world!~%\")' >&2");
    '';
}
