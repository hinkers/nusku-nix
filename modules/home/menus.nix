# The menus' helpers and the launcher clean-up. The menus themselves are the Nusku shell's
# (config/quickshell/nusku/menus: launcher, clipboard, wallpaper, keybinds, power, calendar);
# this packages what they call by name: nusku-menu-keybinds (the keybind search reads niri's
# config through it) and nusku-browser (Super + B). niri's own keybind list is Super + Shift + /.
{ osConfig, lib, pkgs, ... }:
let
  scripts = import ../../lib/scripts.nix { inherit pkgs lib; };
  niri = osConfig.programs.niri.package; # the same niri the session runs

  menuScripts = [
    # Super + /: lists the binds in niri's config (config.kdl and its includes) and runs them.
    (scripts.mkScript {
      name = "nusku-menu-keybinds";
      deps = with pkgs; [ coreutils niri ];
    })
    # gtk-launch (gtk3) starts the browser's desktop entry; xdg-mime reads the default.
    (scripts.mkScript {
      name = "nusku-browser";
      deps = with pkgs; [ xdg-utils gtk3 libnotify ];
    })
  ];

  # nusku-arch config/applications/overrides.list `hide` lines: launcher entries nobody opens
  # from the menu. A NoDisplay entry of the same id in the user's profile hides the app's own
  # (harmless when the app isn't installed). Of nusku-arch's two `icon` swaps, yazi's is in
  # shell.nix (with the Yazi app); spotify-launcher isn't in nixpkgs.
  hidden = [
    # Developer and system tools
    "assistant" "designer" "linguist" "qdbusviewer" "qv4l2" "qvidcap" "lstopo" "xgps"
    "xgpsspeed" "xfce4-about" "blueman-adapters" "thunar-volman-settings"
    # Theme tools: Nusku sets these up.
    "qt5ct" "qt6ct" "kvantummanager"
  ];
in
{
  xdg.desktopEntries = lib.genAttrs hidden (id: {
    name = id;
    noDisplay = true;
  });

  # cliphist and wl-clipboard: the shell's clipboard menu (the history is kept by the niri
  # session's `wl-paste --watch cliphist store`, config/niri/config.kdl).
  home.packages = menuScripts ++ (with pkgs; [ cliphist wl-clipboard ]);
}
