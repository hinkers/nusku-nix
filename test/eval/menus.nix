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
  # nusku-arch config/applications/overrides.list, `hide` lines. Deliberately repeated from
  # modules/home/menus.nix: this copy is checked against nusku-arch's list, not against the module.
  hidden = [
    "assistant" "designer" "linguist" "qdbusviewer" "qv4l2" "qvidcap" "lstopo" "xgps"
    "xgpsspeed" "xfce4-about" "rofi" "rofi-theme-selector" "blueman-adapters"
    "thunar-volman-settings" "qt5ct" "qt6ct" "kvantummanager"
  ];
  menus = [ "nusku-menu-keybinds" "nusku-menu-clipboard" "nusku-browser" ];
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
    builtins.all (p: has p (scriptText "nusku-menu-keybinds")) [ "rofi" "libnotify" "niri" ]
    && builtins.all (p: has p (scriptText "nusku-menu-clipboard")) [ "rofi" "cliphist" "wl-clipboard" ]
    && builtins.all (p: has p (scriptText "nusku-browser")) [ "xdg-utils" "gtk+3" "libnotify" ];
  "menus: niri msg is the session's niri" =
    has (builtins.unsafeDiscardStringContext "${full.programs.niri.package}/bin")
      (scriptText "nusku-menu-keybinds");
  "menus: rofi theme nusku in every menu" =
    builtins.all (n: has "-theme nusku" (read (../../scripts + "/${n}")))
      [ "nusku-menu-keybinds" "nusku-menu-clipboard" ];
  "menus: keybind menu reads niri's config.kdl and follows its includes" =
    let k = read ../../scripts/nusku-menu-keybinds; in
    has "niri/config.kdl" k && has "include" k && has "niri msg action" k;
  "menus: both bind layouts call them by name" =
    builtins.all (f: let k = read (../../config/niri + "/${f}"); in
      builtins.all (n: has ''spawn "${n}"'' k) menus) [ "binds-niri.kdl" "binds-nusku.kdl" ];

  # --- launcher clean-up ---------------------------------------------------------------------
  "launcher: nusku-arch's hidden entries are NoDisplay overrides" =
    builtins.all (id: hm.xdg.desktopEntries ? ${id} && hm.xdg.desktopEntries.${id}.noDisplay) hidden
    && builtins.length (builtins.attrNames hm.xdg.desktopEntries) >= builtins.length hidden;
}
