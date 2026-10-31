{ config, lib, ... }:
{
  imports = [
    ./options.nix
    ./base.nix
    ./gpu.nix
  ];

  networking.hostName = config.nusku.hostname;

  # The release the first Nusku hosts were installed with; never bump it on an existing host.
  system.stateVersion = lib.mkDefault "26.05";
}
