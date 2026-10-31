# The shell and terminal tools: nusku-arch's zshrc/zprofile (zsh itself is the login shell,
# modules/nixos/base.nix) and Starship config, the fastfetch greeting (nusku-fetch; a random
# Gen 1-3 Pokémon via krabby when the `pokemon` app is picked), btop and Yazi (picked app) themed
# by catppuccin/nix. ~/.config/nusku/local.zsh is the user's (created in hyprland.nix).
{ osConfig, lib, pkgs, ... }:
let
  scripts = import ../../lib/scripts.nix { inherit pkgs lib; };
  picked = id: builtins.elem id osConfig.nusku.apps;

  # krabby is not a dependency: nusku-fetch shows a Pokémon only when the user's profile has it.
  nusku-fetch = scripts.mkScript {
    name = "nusku-fetch";
    deps = [ pkgs.fastfetch ];
  };
in
{
  # Plain files, not HM's programs.zsh: nusku-arch's zshrc as is (it sources local.zsh last).
  home.file.".zshrc".source = ../../config/zsh/zshrc;
  home.file.".zprofile".source = ../../config/zsh/zprofile;

  # nusku-arch's Starship config is already the Catppuccin powerline preset (Mocha palette);
  # catppuccin/nix's starship module would only re-set that palette through programs.starship.
  xdg.configFile."starship.toml".source = ../../config/starship.toml;
  catppuccin.starship.enable = false;

  # fastfetch has no catppuccin/nix module; nusku-arch's config carries Mocha colours.
  xdg.configFile."fastfetch/config.jsonc".source = ../../config/fastfetch/config.jsonc;

  # catppuccin/nix (autoEnable) adds the Mocha theme and sets color_theme. HM writes btop.conf
  # read-only, so changes made in btop's own menu last until it exits (nusku-arch copied the file
  # once instead); change settings here.
  programs.btop = {
    enable = true;
    settings = {
      theme_background = true;
      truecolor = true;
      rounded_corners = true;
    };
  };

  # Yazi (System tools app): catppuccin/nix's Mocha flavour in the host accent replaces
  # nusku-arch's rendered theme.toml; yazi.toml is nusku-arch's. extraPackages are nusku-arch's
  # preview helpers (ffmpeg 7zip poppler resvg chafa), on yazi's PATH.
  programs.yazi = lib.mkIf (picked "yazi") {
    enable = true;
    extraPackages = with pkgs; [ ffmpeg _7zz poppler-utils resvg chafa ];
  };
  xdg.configFile."yazi/yazi.toml" = lib.mkIf (picked "yazi") {
    source = ../../config/yazi/yazi.toml;
  };

  home.packages = (with pkgs; [
    starship
    fzf
    bat
    eza
    zoxide
    fastfetch
  ]) ++ [ nusku-fetch ] ++ lib.optional (picked "pokemon") pkgs.krabby;
}
