{
  description = "Nusku: a Catppuccin Mocha Hyprland desktop on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkHosts = dir: import ./lib/hosts.nix { inherit inputs dir; };
      catalogue = import ./lib/catalogue.nix;

      # Test fixtures are only ever checks, never nixosConfigurations.
      fixtures = mkHosts ./test/fixtures/hosts;
      hostChecks = lib.mapAttrs (_: host: host.config.system.build.toplevel) fixtures;

      # test/eval/<file>.nix -> checks.eval-<file>: an attrset of named booleans that must all
      # be true; evaluation fails listing the false ones.
      evalChecks = lib.mapAttrs'
        (file: _:
          let
            name = lib.removeSuffix ".nix" file;
            asserts = import (./test/eval + "/${file}") {
              inherit self lib pkgs catalogue;
              hosts = fixtures;
            };
            failed = builtins.attrNames (lib.filterAttrs (_: ok: ok != true) asserts);
          in
          lib.nameValuePair "eval-${name}" (
            if failed == [ ] then pkgs.runCommand "eval-${name}" { } "touch $out"
            else throw "eval test ${file} failed:\n  - ${lib.concatStringsSep "\n  - " failed}"
          ))
        (lib.filterAttrs (f: t: t == "regular" && lib.hasSuffix ".nix" f) (builtins.readDir ./test/eval));
    in
    {
      nixosConfigurations = mkHosts ./hosts;

      checks.${system} = hostChecks // evalChecks;

      lib = {
        inherit catalogue mkHosts;
      };
    };
}
