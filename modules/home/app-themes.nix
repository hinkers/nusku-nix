# Catppuccin for picked apps that are plain packages (modules/nixos/apps.nix): catppuccin/nix's
# autoEnable only reaches apps run through HM's programs.<app>, so these use its theme files
# (config.catppuccin.sources) directly. Files the user may edit are seeded once, when missing,
# so their own changes stay (as btop.conf, shell.nix).
#  - lazygit (lazygit or neovim picked): LG_CONFIG_FILE loads catppuccin's theme (accent) and then
#    the user's own ~/.config/lazygit/config.yml (seeded empty: lazygit won't start when a file
#    named there is missing). catppuccin/nix's module would leave the user's file out.
#  - Zathura: zathurarc seeded with an include of catppuccin's theme, linked beside it.
#  - MangoHud: MangoHud.conf seeded from catppuccin's.
#  - OBS: catppuccin's themes in obs-studio/themes; OBS has to be told once, in
#    Settings > Appearance > Theme: Catppuccin Mocha.
{ osConfig, config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkMerge;
  inherit (config.catppuccin) sources flavor accent;
  picked = id: builtins.elem id osConfig.nusku.apps;
  configHome = config.xdg.configHome;

  # Activation that writes FILE (absolute) with COMMAND only when nothing is there yet.
  seed = file: command: lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${file}" ] && [ ! -L "${file}" ]; then
      run ${command}
    fi
  '';

  lazygitConfig = "${configHome}/lazygit/config.yml";
  zathuraTheme = "zathura/catppuccin-${flavor}";
  zathurarc = pkgs.writeText "zathurarc" ''
    include ${configHome}/${zathuraTheme}
  '';
  obsTheme = "Catppuccin_${lib.toSentenceCase flavor}.ovt";
in
mkMerge [
  (mkIf (picked "lazygit" || picked "neovim") {
    home.sessionVariables.LG_CONFIG_FILE =
      "${sources.lazygit}/${flavor}/${accent}.yml,${lazygitConfig}";
    home.activation.nuskuLazygitConfig =
      seed lazygitConfig ''install -D -m 644 /dev/null "${lazygitConfig}"'';
  })

  (mkIf (picked "zathura") {
    xdg.configFile.${zathuraTheme}.source = "${sources.zathura}/catppuccin-${flavor}";
    home.activation.nuskuZathuraConfig = seed "${configHome}/zathura/zathurarc"
      ''install -D -m 644 ${zathurarc} "${configHome}/zathura/zathurarc"'';
  })

  (mkIf (picked "mangohud") {
    home.activation.nuskuMangohudConfig = seed "${configHome}/MangoHud/MangoHud.conf"
      ''install -D -m 644 "${sources.mangohud}/${flavor}/MangoHud.conf" "${configHome}/MangoHud/MangoHud.conf"'';
  })

  (mkIf (picked "obs") {
    xdg.configFile = {
      "obs-studio/themes/Catppuccin.obt".source = "${sources.obs}/Catppuccin.obt";
      "obs-studio/themes/${obsTheme}".source = "${sources.obs}/${obsTheme}";
    };
  })
]
