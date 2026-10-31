# The bar and panels: nusku-arch's Waybar (one quick-settings pill), the swaync quick-settings
# panel and pop-ups, the quick-settings scripts and rofi pickers, and the clock's drop-down
# calendar. autostart.lua starts `waybar` and `systemctl --user start swaync`.
{ config, lib, pkgs, ... }:
let
  scripts = import ../../lib/scripts.nix { inherit pkgs lib; };

  nusku-quick = scripts.mkScript {
    name = "nusku-quick";
    deps = with pkgs; [
      coreutils gnugrep procps util-linux libnotify
      networkmanager bluez swaynotificationcenter wireplumber power-profiles-daemon
      hyprsunset hypridle
    ];
  };
  nusku-menu-wifi = scripts.mkScript {
    name = "nusku-menu-wifi";
    deps = with pkgs; [ coreutils gnused gawk networkmanager rofi libnotify kitty ];
  };
  nusku-menu-bluetooth = scripts.mkScript {
    name = "nusku-menu-bluetooth";
    deps = with pkgs; [ coreutils gnused gnugrep gawk bluez util-linux rofi libnotify blueman ];
  };
  nusku-swaync-config = scripts.mkScript {
    name = "nusku-swaync-config";
    deps = with pkgs; [ coreutils gnused jq power-profiles-daemon ];
  };

  # nusku-arch's panel template; nusku-swaync-config fills in this machine's backlight device and
  # power profiles when swaync starts (Nix can't see the hardware).
  swayncTemplate = ../../config/swaync/config.template.json;

  # Python + GTK4 with the GI typelibs it imports (Gtk, Gdk, Gtk4LayerShell, EDataServer, ECal,
  # ICalGLib) on GI_TYPELIB_PATH via wrapGAppsHook4. The script preloads gtk4-layer-shell
  # (it must load before libwayland-client) from NUSKU_LAYER_SHELL.
  calendarPython = pkgs.python3.withPackages (p: [ p.pygobject3 ]);
  layerShellLib = "${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so";
  calendarTypelibs = with pkgs; [ gtk4-layer-shell evolution-data-server libical ];
  nusku-calendar = pkgs.stdenv.mkDerivation {
    pname = "nusku-calendar";
    version = "1";
    src = ../../scripts/nusku-calendar;
    dontUnpack = true;
    nativeBuildInputs = with pkgs; [ wrapGAppsHook4 gobject-introspection ];
    buildInputs = with pkgs; [ calendarPython gtk4 gtk4-layer-shell evolution-data-server libical ];
    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/nusku-calendar
      substituteInPlace $out/bin/nusku-calendar \
        --replace-fail "#!/usr/bin/env python3" "#!${calendarPython}/bin/python3"
      runHook postInstall
    '';
    # The hook only collects typelibs it finds in the inputs' dev outputs (gtk4's propagated
    # deps), so the layer-shell, EDS and libical ones are added explicitly.
    preFixup = ''
      gappsWrapperArgs+=(
        --set NUSKU_LAYER_SHELL "${layerShellLib}"
        --prefix GI_TYPELIB_PATH : "${lib.makeSearchPath "lib/girepository-1.0" calendarTypelibs}"
      )
    '';
    meta.mainProgram = "nusku-calendar";
  };
in
{
  xdg.configFile = {
    "waybar/config.jsonc".source = ../../config/waybar/config.jsonc;
    "waybar/style.css".source = ../../config/waybar/style.css;
    # config.json is a plain file written by nusku-swaync-config (below), not a store link.
    "swaync/config.json".enable = false;
  };

  services.swaync = {
    enable = true;
    style = ../../config/swaync/style.css;
  };
  systemd.user.services.swaync = {
    Unit.X-Restart-Triggers = [ "${swayncTemplate}" ];
    # The panel's buttons run commands by name (nusku-quick, nusku-menu-power, hyprshot, ...).
    Service.Environment = [
      "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
    ];
    # "-": if the config can't be written, swaync still starts (with the last or default one).
    Service.ExecStartPre = "-${nusku-swaync-config}/bin/nusku-swaync-config ${swayncTemplate} ${config.xdg.configHome}/swaync/config.json";
  };

  # nusku-arch's own Waybar and swaync styles (they import ~/.config/nusku/theme/colors.css).
  catppuccin.waybar.enable = false;
  catppuccin.swaync.enable = false;

  home.packages = (with pkgs; [
    waybar
    networkmanagerapplet # nm-connection-editor (floated by rules.lua)
  ]) ++ [ nusku-quick nusku-menu-wifi nusku-menu-bluetooth nusku-swaync-config nusku-calendar ];
}
