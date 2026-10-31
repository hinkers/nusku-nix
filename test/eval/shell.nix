# Named eval assertions (flake check `eval-shell`): zsh + Starship, the fastfetch greeting with
# the optional Pokémon, btop and Yazi.
{ hosts, lib, ... }:
let
  full = hosts.vm-full.config; # apps: firefox, obsidian
  # The same host with the Pokémon and Yazi apps picked (settings.json is the only source of
  # nusku.apps; reading home-manager options doesn't run the catalogue assertion).
  picked = (hosts.vm-full.extendModules {
    modules = [{ nusku.apps = lib.mkForce [ "pokemon" "yazi" ]; nusku.accent = lib.mkForce "peach"; }];
  }).config;
  hmOf = c: c.home-manager.users.${c.nusku.user};
  hm = hmOf full;
  hmP = hmOf picked;
  has = lib.hasInfix;
  read = f: builtins.readFile f;
  pkgNamesOf = h: map (p: p.pname or p.name or "") h.home.packages;
  pkgNames = pkgNamesOf hm;
  pkgByName = n: lib.findFirst (p: (p.pname or p.name or "") == n) null hm.home.packages;
  homeFile = name: hm.home.file.${name};
in
{
  # --- zsh -----------------------------------------------------------------------------------
  "zsh: nusku-arch zshrc and zprofile linked" =
    (homeFile ".zshrc").source == ../../config/zsh/zshrc
    && (homeFile ".zprofile").source == ../../config/zsh/zprofile;
  "zsh: login shell (system), HM's own zsh config not used" =
    full.programs.zsh.enable
    && full.users.users.${full.nusku.user}.shell.pname or "" == "zsh"
    && !hm.programs.zsh.enable;
  "zsh: tools the zshrc uses are installed" =
    builtins.all (n: builtins.elem n pkgNames) [ "starship" "eza" "bat" "fzf" "zoxide" "fastfetch" ];
  "zsh: local.zsh sourced, created by activation, never managed" =
    has ''source "$HOME/.config/nusku/local.zsh"'' (read ../../config/zsh/zshrc)
    && !(builtins.any (f: lib.hasSuffix "local.zsh" f.target) (builtins.attrValues hm.home.file))
    && has "local.zsh" (lib.concatStrings (map (e: e.data) (builtins.attrValues hm.home.activation)));

  # --- starship ------------------------------------------------------------------------------
  "starship: nusku-arch config linked; catppuccin's starship module off" =
    hm.xdg.configFile."starship.toml".source == ../../config/starship.toml
    && !hm.catppuccin.starship.enable && !hm.programs.starship.enable
    && has "palette = 'catppuccin_mocha'" (read ../../config/starship.toml);

  # --- fastfetch and Pokémon -----------------------------------------------------------------
  "fastfetch: nusku-arch config linked; nusku-fetch installed with fastfetch on its PATH" =
    hm.xdg.configFile."fastfetch/config.jsonc".source == ../../config/fastfetch/config.jsonc
    && pkgByName "nusku-fetch" != null
    && has "fastfetch" (pkgByName "nusku-fetch").text;
  "pokemon picked: krabby installed" = builtins.elem "krabby" (pkgNamesOf hmP);
  "pokemon not picked: no krabby" = !(builtins.elem "krabby" pkgNames);
  "nusku-fetch finds krabby on the user's PATH (not a fixed dependency)" =
    !(has "-krabby-" (pkgByName "nusku-fetch").text); # no krabby store path on its PATH

  # --- btop ----------------------------------------------------------------------------------
  "btop: HM program with catppuccin's Mocha theme and nusku-arch's settings" =
    hm.programs.btop.enable && hm.catppuccin.btop.enable
    && hm.programs.btop.settings.color_theme == "catppuccin_mocha.theme"
    && hm.programs.btop.settings.theme_background && hm.programs.btop.settings.rounded_corners
    && hm.xdg.configFile ? "btop/themes/catppuccin_mocha.theme";

  # --- yazi ----------------------------------------------------------------------------------
  "yazi picked: HM program, catppuccin theme in the host accent, nusku-arch yazi.toml" =
    hmP.programs.yazi.enable && hmP.catppuccin.yazi.enable
    && has "catppuccin-mocha-peach.toml" (toString hmP.xdg.configFile."yazi/theme.toml".source)
    && hmP.xdg.configFile."yazi/yazi.toml".source == ../../config/yazi/yazi.toml
    && builtins.all (n: builtins.elem n (map (p: p.pname or p.name or "") hmP.programs.yazi.extraPackages))
      [ "ffmpeg" "7zz" "poppler-utils" "resvg" "chafa" ];
  "yazi not picked: not installed or configured" =
    !hm.programs.yazi.enable && !(hm.xdg.configFile ? "yazi/yazi.toml" && hm.xdg.configFile."yazi/yazi.toml".enable);
}
