# Home Manager entry for the Nusku user (wired in modules/nixos/default.nix). Each feature is
# its own module here, listed in `imports`. Modules read the host answers from
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
    ./app-themes.nix
    ./neovim.nix
    ./langs.nix
    ./commands.nix
  ];

  home.username = osConfig.nusku.user;
  home.homeDirectory = "/home/${osConfig.nusku.user}";
  # Fixed, unlike system.stateVersion (settings.json "stateVersion"): Home Manager's state starts
  # at Nusku's first build, made with this flake's Home Manager, whatever release NixOS was
  # installed from (a newer ISO's release could be one this Home Manager doesn't know; an older
  # one would change its defaults, e.g. Firefox's profile back to ~/.mozilla). Never change it.
  home.stateVersion = "26.05";

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
    accent = osConfig.nusku.internal.accent;
  };

  xdg.enable = true;
}
