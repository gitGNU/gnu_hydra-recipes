{ pkgs, ... }:

{
  machine = { config, pkgs, ... }: { };

  testScript =
    ''
      $machine->mustSucceed("touch --version");
      $machine->mustSucceed("tar --version");
      $machine->mustSucceed("cpio --version");
      $machine->mustSucceed("guile --version");
      $machine->mustSucceed("guile -c '(format #t \"hello, world!~%\")'");
    '';
}
