# The shell and terminal tools: nusku-arch's zshrc/zprofile (zsh itself is the login shell,
# modules/nixos/base.nix) and Starship config, the fastfetch greeting (nusku-fetch; a random
# Gen 1-3 Pokémon via krabby when the `pokemon` app is picked), btop (nusku-arch theme, writable
# config) and Yazi (picked app; catppuccin/nix theme in the accent, Papirus-friendly launcher icon).
# ~/.config/nusku/local.zsh is the user's (created in hyprland.nix).
{ osConfig, config, lib, pkgs, ... }:
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

  # btop rewrites btop.conf on exit, so (as on nusku-arch) it is a writable copy made once by the
  # activation step below, not a store link; HM's programs.btop (and catppuccin's btop module,
  # which needs it) would make it read-only. The theme file is nusku-arch's vendored Catppuccin
  # Mocha (btop.conf: color_theme = "catppuccin_mocha").
  xdg.configFile."btop/themes/catppuccin_mocha.theme".source =
    ../../config/btop/themes/catppuccin_mocha.theme;
  home.activation.nuskuBtopConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    btopConf="${config.xdg.configHome}/btop/btop.conf"
    if [ ! -e "$btopConf" ] && [ ! -L "$btopConf" ]; then
      run install -D -m 644 ${../../config/btop/btop.conf} "$btopConf"
    fi
  '';

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
  # nusku-arch overrides.list `icon yazi.desktop mc`: Papirus has no yazi icon. A copy of
  # nixpkgs' yazi.desktop with only the icon changed (HM puts it ahead of yazi's own).
  xdg.desktopEntries.yazi = lib.mkIf (picked "yazi") {
    name = "Yazi File Manager";
    icon = "mc";
    comment = "Blazing fast terminal file manager written in Rust, based on async I/O";
    terminal = true;
    exec = "yazi %f";
    type = "Application";
    mimeType = [ "inode/directory" ];
    categories = [ "System" "FileManager" "FileTools" "ConsoleOnly" ];
    settings = {
      TryExec = "yazi";
      Keywords = "File;Manager;Explorer;Browser;Launcher";
    };
  };

  home.packages = (with pkgs; [
    btop
    starship
    fzf
    bat
    eza
    zoxide
    fastfetch
  ]) ++ [ nusku-fetch ] ++ lib.optional (picked "pokemon") pkgs.krabby;
}
