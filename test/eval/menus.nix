# Named eval assertions (flake check `eval-menus`): Rofi, the power / clipboard / keybind menus,
# nusku-browser (SUPER + B) and the launcher clean-up.
{ hosts, lib, ... }:
let
  full = hosts.vm-full.config;
  hm = full.home-manager.users.${full.nusku.user};
  has = lib.hasInfix;
  cfgFile = name: hm.xdg.configFile.${name};
  pkgByName = n: lib.findFirst (p: (p.pname or p.name or "") == n) null hm.home.packages;
  pkgNames = map (p: p.pname or p.name or "") hm.home.packages;
  # writeShellApplication's text attribute (the file it writes): no build, no IFD.
  scriptText = n: (pkgByName n).text;
  read = f: builtins.readFile f;
  # nusku-arch config/applications/overrides.list, `hide` lines.
  hidden = [
    "assistant" "designer" "linguist" "qdbusviewer" "qv4l2" "qvidcap" "lstopo" "xgps"
    "xgpsspeed" "xfce4-about" "rofi" "rofi-theme-selector" "blueman-adapters"
    "thunar-volman-settings" "qt5ct" "qt6ct" "kvantummanager"
  ];
  menus = [ "nusku-menu-keybinds" "nusku-menu-clipboard" "nusku-menu-power" "nusku-browser" ];
in
{
  # --- rofi ----------------------------------------------------------------------------------
  "rofi: nusku-arch config and the nusku theme linked" =
    (cfgFile "rofi/config.rasi").source == ../../config/rofi/config.rasi
    && (cfgFile "rofi/nusku.rasi").source == ../../config/rofi/nusku.rasi
    && (cfgFile "rofi/catppuccin-mocha.rasi").source == ../../config/rofi/catppuccin-mocha.rasi;
  "rofi: config uses theme nusku; it takes the accent from the rendered colors.rasi" =
    has ''@theme "nusku"'' (read ../../config/rofi/config.rasi)
    && has ''@import "~/.config/nusku/theme/colors"'' (read ../../config/rofi/nusku.rasi)
    && hm.xdg.configFile ? "nusku/theme/colors.rasi"
    && has "@accent" (read ../../config/rofi/nusku.rasi);
  "rofi: package installed; HM programs.rofi (and so catppuccin's rofi theme) not used" =
    builtins.elem "rofi" pkgNames && !hm.programs.rofi.enable;

  # --- menus ---------------------------------------------------------------------------------
  "menus: scripts installed" = builtins.all (n: pkgByName n != null) menus;
  "menus: runtime tools on their PATH" =
    builtins.all (p: has p (scriptText "nusku-menu-keybinds")) [ "rofi" "libnotify" "hyprland" "gnused" ]
    && builtins.all (p: has p (scriptText "nusku-menu-clipboard")) [ "rofi" "cliphist" "wl-clipboard" ]
    && builtins.all (p: has p (scriptText "nusku-menu-power")) [ "rofi" "hyprland" "hyprlock" ]
    && builtins.all (p: has p (scriptText "nusku-browser")) [ "xdg-utils" "gtk+3" "libnotify" ];
  "menus: hyprctl is the session's Hyprland" =
    has (builtins.unsafeDiscardStringContext "${full.programs.hyprland.package}/bin")
      (scriptText "nusku-menu-keybinds");
  "menus: rofi theme nusku in every menu" =
    builtins.all (n: has "-theme nusku" (read (../../scripts + "/${n}")))
      [ "nusku-menu-keybinds" "nusku-menu-clipboard" "nusku-menu-power" ];
  "menus: keybind menu reads bindlib's manifest" =
    has "nusku/keybinds.tsv" (read ../../scripts/nusku-menu-keybinds)
    && has "/nusku/keybinds.tsv" (read ../../config/hypr/bindlib.lua);
  "menus: the binds and the swaync power button call them by name" =
    let k = read ../../config/hypr/keybinds.lua; in
    builtins.all (n: has ''exec_cmd("${n}")'' k) menus
    && has "; nusku-menu-power\"" (read ../../config/swaync/config.template.json);

  # --- launcher clean-up ---------------------------------------------------------------------
  "launcher: nusku-arch's hidden entries are NoDisplay overrides" =
    builtins.all (id: hm.xdg.desktopEntries ? ${id} && hm.xdg.desktopEntries.${id}.noDisplay) hidden
    && builtins.length (builtins.attrNames hm.xdg.desktopEntries) >= builtins.length hidden;
}
