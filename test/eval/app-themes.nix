# Named eval assertions (flake check `eval-app-themes`): Catppuccin for the picked apps that are
# plain packages (modules/home/app-themes.nix): lazygit, Zathura, MangoHud and OBS.
{ hosts, lib, ... }:
let
  # vm-full with other apps and accent (settings.json is the only source of nusku.apps; reading
  # home-manager options doesn't run the catalogue assertion).
  pick = apps: (hosts.vm-full.extendModules {
    modules = [{ nusku.apps = lib.mkForce apps; nusku.accent = lib.mkForce "peach"; }];
  }).config;
  hmOf = c: c.home-manager.users.${c.nusku.user};
  all = hmOf (pick [ "lazygit" "zathura" "mangohud" "obs" ]);
  nvim = hmOf (pick [ "neovim" ]);
  none = hmOf (pick [ "firefox" ]);
  has = lib.hasInfix;
  act = h: n: h.home.activation.${n}.data or "";
  linked = h: n: h.xdg.configFile ? ${n} && h.xdg.configFile.${n}.enable;
  src = h: n: toString h.xdg.configFile.${n}.source;
  lg = h: h.home.sessionVariables.LG_CONFIG_FILE or "";
  seedsOnce = a: file: has ''if [ ! -e "${file}" ] && [ ! -L "${file}" ]; then'' a;
in
{
  "lazygit: catppuccin's theme in the accent, then the user's own config.yml" =
    let c = "${all.xdg.configHome}/lazygit/config.yml"; in
    has "/mocha/peach.yml," (lg all) && lib.hasSuffix ",${c}" (lg all)
    && !(linked all "lazygit/config.yml");
  "lazygit: config.yml seeded empty, only if missing" =
    let c = "${all.xdg.configHome}/lazygit/config.yml"; in
    seedsOnce (act all "nuskuLazygitConfig") c
    && has "install -D -m 644 /dev/null" (act all "nuskuLazygitConfig");
  "lazygit: themed when only Neovim is picked (LazyVim runs it)" =
    has "/mocha/peach.yml," (lg nvim) && act nvim "nuskuLazygitConfig" != "";

  "zathura: catppuccin's theme linked; zathurarc seeded with an include of it" =
    let rc = "${all.xdg.configHome}/zathura/zathurarc"; in
    linked all "zathura/catppuccin-mocha"
    && lib.hasSuffix "/catppuccin-mocha" (src all "zathura/catppuccin-mocha")
    && seedsOnce (act all "nuskuZathuraConfig") rc
    && !(linked all "zathura/zathurarc") && !all.programs.zathura.enable;

  "mangohud: MangoHud.conf seeded from catppuccin's, only if missing" =
    let a = act all "nuskuMangohudConfig"; in
    seedsOnce a "${all.xdg.configHome}/MangoHud/MangoHud.conf"
    && has "/mocha/MangoHud.conf" a && !all.programs.mangohud.enable;

  "obs: catppuccin's themes in obs-studio/themes" =
    linked all "obs-studio/themes/Catppuccin.obt"
    && linked all "obs-studio/themes/Catppuccin_Mocha.ovt";

  "not picked: none of it" =
    lg none == ""
    && builtins.all (n: !(none.home.activation ? ${n}))
      [ "nuskuLazygitConfig" "nuskuZathuraConfig" "nuskuMangohudConfig" ]
    && !(linked none "zathura/catppuccin-mocha")
    && !(linked none "obs-studio/themes/Catppuccin.obt");
}
