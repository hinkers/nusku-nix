# One nixosSystem per subdirectory of `dir` that has a settings.json (the installer's answers)
# and a hardware-configuration.nix, plus its installer.nix when there is one: the boot and
# encryption settings the NixOS installer wrote to /etc/nixos/configuration.nix (install.sh,
# lib/installer-config.nix). A missing or empty `dir` gives no hosts.
# `extraModules` are added to every host (only test/hyperv/hosts.nix passes any).
{ inputs, dir, extraModules ? [ ] }:
let
  lib = inputs.nixpkgs.lib;
  entries = if builtins.pathExists dir then builtins.readDir dir else { };
  isHost = name: type: type == "directory" && builtins.pathExists (dir + "/${name}/settings.json");
  mkHost = name: _:
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
        settings = builtins.fromJSON (builtins.readFile (dir + "/${name}/settings.json"));
      };
      modules = [
        (dir + "/${name}/hardware-configuration.nix")
        ../modules/nixos
      ]
      ++ lib.optional (builtins.pathExists (dir + "/${name}/installer.nix")) (dir + "/${name}/installer.nix")
      ++ extraModules;
    };
in
lib.mapAttrs mkHost (lib.filterAttrs isHost entries)
