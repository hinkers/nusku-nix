# Rofi and the menus: nusku-arch's rofi config and `nusku` theme (Catppuccin Mocha + the accent
# from ~/.config/nusku/theme/colors.rasi), the keybind and clipboard menus, nusku-browser
# (Super + B) and the launcher clean-up. The wallpaper menu is in niri.nix; the Wi-Fi and
# Bluetooth pickers in panels.nix. Binds (config/niri/binds-*.kdl) call the scripts by name; the
# app launcher and the power menu are the Nusku shell's. niri's own keybind list is
# Super + Shift + /.
{ osConfig, lib, pkgs, ... }:
let
  scripts = import ../../lib/scripts.nix { inherit pkgs lib; };
  niri = osConfig.programs.niri.package; # the same niri the session runs

  menuScripts = [
    # Super + /: reads the niri config it lists (config.kdl and its includes).
    (scripts.mkScript {
      name = "nusku-menu-keybinds";
      deps = with pkgs; [ coreutils rofi libnotify niri ];
    })
    (scripts.mkScript {
      name = "nusku-menu-clipboard";
      deps = with pkgs; [ cliphist rofi wl-clipboard ];
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
    "xgpsspeed" "xfce4-about" "rofi" "rofi-theme-selector" "blueman-adapters"
    "thunar-volman-settings"
    # Theme tools: Nusku sets these up.
    "qt5ct" "qt6ct" "kvantummanager"
  ];
in
{
  # Not HM's programs.rofi: it would write its own config.rasi (and catppuccin/nix's rofi theme,
  # which has no accent). The menus ask for `-theme nusku`.
  xdg.configFile = {
    "rofi/config.rasi".source = ../../config/rofi/config.rasi;
    "rofi/nusku.rasi".source = ../../config/rofi/nusku.rasi;
    "rofi/catppuccin-mocha.rasi".source = ../../config/rofi/catppuccin-mocha.rasi;
  };

  xdg.desktopEntries = lib.genAttrs hidden (id: {
    name = id;
    noDisplay = true;
  });

  home.packages = [ pkgs.rofi ] ++ menuScripts;
}
