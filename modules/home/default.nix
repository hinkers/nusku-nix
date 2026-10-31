# Home Manager entry for the Nusku user (wired in modules/nixos/default.nix). Each feature is
# its own module here, listed in `imports`. Modules read the host answers from
# `osConfig.nusku` (accent, apps, langs, ...), the palette from lib/palette.nix, and package
# scripts with lib/scripts.nix.
{ osConfig, lib, ... }:
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
  # Home Manager's state starts at the first Nusku build, made with this flake's Home Manager
  # (26.05 or later), so it never goes below 26.05 even on a machine installed from an older
  # NixOS: below it, Home Manager's defaults differ (Firefox's profile moves to ~/.mozilla).
  home.stateVersion =
    let installed = osConfig.nusku.stateVersion; in
    if lib.versionOlder installed "26.05" then "26.05" else installed;

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
    accent = osConfig.nusku.internal.accent;
  };

  xdg.enable = true;
}
