# One nixosSystem per subdirectory of `dir` that has a settings.json (the installer's answers)
# and a hardware-configuration.nix. A missing or empty `dir` gives no hosts.
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
      ] ++ extraModules;
    };
in
lib.mapAttrs mkHost (lib.filterAttrs isHost entries)
