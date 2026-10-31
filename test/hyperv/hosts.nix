# The Hyper-V test VM's variant of a host: NAME-hyperv-test, the same system as NAME plus
# ./guest.nix (sshd, passwordless sudo, autologin), which the test loop needs to keep reaching
# the VM after the first switch (test/hyperv/README.md).
#
# flake.nix makes one for every host in hosts/ (and test/fixtures/hosts/) whose settings.json
# has gpu "vm"; a host for real hardware never gets one, and guest.nix refuses to build for one
# (test/eval/hyperv.nix checks both). NAME itself is never changed: the variant is a separate
# flake output, built only when asked for by name (install.sh and nusku-rebuild build it when
# NUSKU_FLAKE_ATTR=NAME-hyperv-test, lib/sh/rebuild.sh).
#
# `all = true` makes a variant for every host, gpu "vm" or not (only for the eval test that shows
# guest.nix refuses the others).
{ inputs, dir, all ? false }:
let
  lib = inputs.nixpkgs.lib;
  settingsOf = name: builtins.fromJSON (builtins.readFile (dir + "/${name}/settings.json"));
  isVm = name: ((settingsOf name).gpu or null) == "vm";
  hosts = import ../../lib/hosts.nix { inherit inputs dir; extraModules = [ ./guest.nix ]; };
in
lib.mapAttrs' (name: host: lib.nameValuePair "${name}-hyperv-test" host)
  (lib.filterAttrs (name: _: all || isVm name) hosts)
