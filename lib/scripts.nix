# Packages one of scripts/<name> so its runtime tools are on PATH, whatever PATH the caller has
# (niri binds, systemd units, the Nusku shell). Built with writeShellApplication: the script's own
# shebang line is dropped (writeShellApplication adds its own) and shellcheck runs at build time.
# No `set` options are added: each script's own `set` line decides (some nusku-arch scripts
# deliberately run without errexit). Don't read the script back from $0: its first lines are
# writeShellApplication's.
#
#   scripts = import ../../lib/scripts.nix { inherit pkgs lib; };
#   home.packages = [ (scripts.mkScript { name = "nusku-foo"; deps = [ pkgs.jq ]; }) ];
{ pkgs, lib }:
{
  mkScript = { name, deps ? [ ], env ? { } }:
    let
      src = builtins.readFile (../scripts + "/${name}");
      lines = lib.splitString "\n" src;
      body = if lib.hasPrefix "#!" (builtins.head lines)
        then lib.concatStringsSep "\n" (builtins.tail lines)
        else src;
    in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = deps;
      runtimeEnv = if env == { } then null else env;
      bashOptions = [ ];
      text = body;
    };
}
