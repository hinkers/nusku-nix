# Named eval assertions (flake check `eval-menus`): the menus' helpers (the keybind search's
# nusku-menu-keybinds, nusku-browser for Super + B), no rofi, and the launcher clean-up.
{ hosts, lib, ... }:
let
  full = hosts.vm-full.config;
  hm = full.home-manager.users.${full.nusku.user};
  has = lib.hasInfix;
  pkgByName = n: lib.findFirst (p: (p.pname or p.name or "") == n) null hm.home.packages;
  pkgNames = map (p: p.pname or p.name or "") hm.home.packages;
  # writeShellApplication's text attribute (the file it writes): no build, no IFD.
  scriptText = n: (pkgByName n).text;
  read = f: builtins.readFile f;
  # nusku-arch config/applications/overrides.list, `hide` lines. Deliberately repeated from
  # modules/home/menus.nix: this copy is checked against nusku-arch's list, not against the module.
  hidden = [
    "assistant" "designer" "linguist" "qdbusviewer" "qv4l2" "qvidcap" "lstopo" "xgps"
    "xgpsspeed" "xfce4-about" "blueman-adapters" "thunar-volman-settings" "qt5ct" "qt6ct"
    "kvantummanager"
  ];
in
{
  # --- the menus' helpers ---------------------------------------------------------------------
  "menus: nusku-menu-keybinds and nusku-browser installed, with their tools" =
    pkgByName "nusku-menu-keybinds" != null && pkgByName "nusku-browser" != null
    && builtins.all (p: has p (scriptText "nusku-browser")) [ "xdg-utils" "gtk+3" "libnotify" ]
    && builtins.all (n: builtins.elem n pkgNames) [ "cliphist" "wl-clipboard" ];
  "menus: the keybind search's niri msg is the session's niri" =
    has (builtins.unsafeDiscardStringContext "${full.programs.niri.package}/bin")
      (scriptText "nusku-menu-keybinds");
  "menus: keybind search reads niri's config.kdl, follows its includes, lists and runs" =
    let k = read ../../scripts/nusku-menu-keybinds; in
    has "niri/config.kdl" k && has "include" k && has "niri msg action" k
    && has "--list" k && has "--run" k
    && has ''"nusku-menu-keybinds", "--list"'' (read ../../config/quickshell/nusku/menus/Keybinds.qml);
  "menus: no rofi (the shell's menus replace it)" =
    !(builtins.elem "rofi" pkgNames) && !hm.programs.rofi.enable
    && !(hm.xdg.configFile ? "rofi/config.rasi") && !(hm.xdg.configFile ? "nusku/theme/colors.rasi")
    && builtins.all (n: pkgByName n == null)
      [ "nusku-menu-clipboard" "nusku-menu-wallpaper" "nusku-menu-wifi" "nusku-menu-bluetooth" "nusku-menu-power" ];
  "menus: Super + B and the shell's menus from both bind layouts" =
    builtins.all (f: let k = read (../../config/niri + "/${f}"); in
      has ''spawn "nusku-browser"'' k
      && builtins.all (m: has ''"qs" "-c" "nusku" "ipc" "call" "${m}" "toggle"'' k) [ "clipboard" "wallpaper" "keybinds" "launcher" ])
      [ "binds-niri.kdl" "binds-nusku.kdl" ];

  # --- launcher clean-up ---------------------------------------------------------------------
  "launcher: nusku-arch's hidden entries are NoDisplay overrides" =
    builtins.all (id: hm.xdg.desktopEntries ? ${id} && hm.xdg.desktopEntries.${id}.noDisplay) hidden
    && builtins.length (builtins.attrNames hm.xdg.desktopEntries) >= builtins.length hidden;
}
