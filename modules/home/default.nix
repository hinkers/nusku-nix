# Home Manager entry for the Nusku user (wired in modules/nixos/default.nix). Each feature is
# its own module here; later tasks add theirs to `imports`. Modules read the host answers from
# `osConfig.nusku` (accent, apps, langs, ...), the palette from lib/palette.nix, and package
# scripts with lib/scripts.nix.
{ osConfig, ... }:
{
  imports = [
    ./theme.nix
    ./hyprland.nix
    ./panels.nix
    ./menus.nix
    ./shell.nix
    ./browsers.nix
    ./neovim.nix
    ./langs.nix
    ./commands.nix
  ];

  home.username = osConfig.nusku.user;
  home.homeDirectory = "/home/${osConfig.nusku.user}";
  # Like system.stateVersion: the release the first Nusku hosts were installed with.
  home.stateVersion = "26.05";

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
    accent = osConfig.nusku.internal.accent;
  };

  xdg.enable = true;
}
