{ pkgs, ... }:

let
  commands =
    [ "ldd" "touch" "tar" "cpio" "grep" "patch"
      "ifconfig" "guile"
    ];
in
{
  machine = { config, pkgs, ... }: {
    # Extra packages wanted in the global environment.
    environment.systemPackages =
      [ pkgs.cpio pkgs.guile_1_9 pkgs.inetutils ];
  };

  testScript =
    ''
       ${pkgs.lib.concatMapStrings
           (cmd: "$machine->mustSucceed(\"${cmd} --version >&2\");")
           commands}

       $machine->mustSucceed("guile -c '(format #t \"hello, world!~%\")' >&2");
    '';
}
