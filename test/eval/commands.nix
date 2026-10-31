# Named eval assertions (flake check `eval-commands`): the everyday commands nusku-rebuild and
# nusku-update are on the user's PATH with their tools. Their behaviour is test/unit/everyday.bats.
{ hosts, lib, ... }:
let
  min = hosts.vm-min.config; # no apps: the commands are there whatever is picked
  hm = min.home-manager.users.${min.nusku.user};
  has = lib.hasInfix;
  pkgByName = n: lib.findFirst (p: (p.pname or p.name or "") == n) { } hm.home.packages;
  # writeShellApplication's text attribute (the file it writes): no build, no IFD.
  scriptText = n: (pkgByName n).text or "";
  binOf = p: builtins.unsafeDiscardStringContext "${p}/bin";
  # The system's own nix and nixos-rebuild, so the commands build with what the system runs.
  systemTools = [ (binOf min.nix.package) (binOf min.system.build.nixos-rebuild) ];
in
{
  "commands: nusku-rebuild and nusku-update installed for the user" =
    pkgByName "nusku-rebuild" != { } && pkgByName "nusku-update" != { };
  "commands: nusku-rebuild has coreutils, nix and nixos-rebuild on its PATH" =
    builtins.all (p: has p (scriptText "nusku-rebuild")) ([ "coreutils" ] ++ systemTools);
  "commands: nusku-update also has git" =
    builtins.all (p: has p (scriptText "nusku-update")) ([ "coreutils" "git" ] ++ systemTools);
  "commands: both build through the checkout's lib/sh/rebuild.sh (nusku_rebuild)" =
    builtins.all (n: has "lib/sh/rebuild.sh" (scriptText n) && has "nusku_rebuild" (scriptText n))
      [ "nusku-rebuild" "nusku-update" ];
}
