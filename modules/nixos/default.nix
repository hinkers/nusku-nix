{ config, lib, inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.catppuccin.nixosModules.catppuccin
    ./options.nix
    ./base.nix
    ./gpu.nix
    ./desktop.nix
  ];

  networking.hostName = config.nusku.hostname;

  # The user's Home Manager config (modules/home). HM modules read the host answers from
  # `osConfig.nusku`; `inputs` is passed through for modules that need a flake input.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    sharedModules = [ inputs.catppuccin.homeModules.catppuccin ];
    users.${config.nusku.user} = import ../home;
  };

  # The release the first Nusku hosts were installed with; never bump it on an existing host.
  system.stateVersion = lib.mkDefault "26.05";
}
