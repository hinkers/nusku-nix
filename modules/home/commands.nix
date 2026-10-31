# The everyday commands: nusku-rebuild (apply your edits) and nusku-update (pull, new flake.lock,
# rebuild). Both find the checkout from ~/.config/nusku/repo (install.sh writes it) or
# $NUSKU_REPO, and build through the checkout's lib/sh/rebuild.sh. nix and nixos-rebuild are the
# system's own, so they build with what the system runs; sudo is the system's wrapper
# (/run/wrappers/bin, on every login's PATH).
{ osConfig, lib, pkgs, ... }:
let
  scripts = import ../../lib/scripts.nix { inherit pkgs lib; };
  system = [ osConfig.nix.package osConfig.system.build.nixos-rebuild ];
in
{
  home.packages = [
    (scripts.mkScript {
      name = "nusku-rebuild";
      deps = [ pkgs.coreutils ] ++ system;
    })
    (scripts.mkScript {
      name = "nusku-update";
      deps = [ pkgs.coreutils pkgs.git ] ++ system;
    })
  ];
}
