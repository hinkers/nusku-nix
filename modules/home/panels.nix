# The bar and panels: the Nusku shell (Quickshell, config/quickshell/nusku: the bar, the quick
# settings panel and the notification pop-ups; it is also the notification server), the
# quick-settings scripts and rofi pickers it calls, and the clock's drop-down calendar. The
# shell is the nusku-shell user service, started with the session.
{ config, lib, pkgs, ... }:
let
  scripts = import ../../lib/scripts.nix { inherit pkgs lib; };
  shellDir = ../../config/quickshell/nusku;

  nusku-quick = scripts.mkScript {
    name = "nusku-quick";
    deps = with pkgs; [
      coreutils gnugrep procps util-linux libnotify
      networkmanager bluez quickshell wireplumber power-profiles-daemon
      wlsunset # systemctl (caffeine: the swayidle unit) comes from the system
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
  # The shell's QML, file by file (so Colors.qml, rendered from lib/palette.nix by theme.nix
  # with the host's accent, can sit next to it).
  xdg.configFile = lib.listToAttrs (map
    (path: lib.nameValuePair "quickshell/nusku/${lib.removePrefix (toString shellDir + "/") (toString path)}" { source = path; })
    (lib.filesystem.listFilesRecursive shellDir)) // {
    "quickshell/nusku/Colors.qml".text = config.xdg.configFile."nusku/theme/Colors.qml".text;
  };

  systemd.user.services.nusku-shell = {
    Unit = {
      Description = "Nusku shell (Quickshell): bar, quick settings, notifications";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # A rebuild that changes the shell restarts it (it also reloads edited files by itself).
      X-Restart-Triggers = [ "${shellDir}" config.xdg.configFile."quickshell/nusku/Colors.qml".text ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/qs -c nusku";
      Restart = "on-failure";
      RestartSec = 2;
      # Its buttons run commands by name (nusku-quick, nusku-menu-power, niri, ...).
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.packages = (with pkgs; [
    quickshell # qs: `qs -c nusku ipc call panel toggle` (Super + N), nusku-quick's dnd
    brightnessctl # the panel's brightness slider
    networkmanagerapplet # nm-connection-editor (floated by a niri window rule)
  ]) ++ [ nusku-quick nusku-menu-wifi nusku-menu-bluetooth nusku-calendar ];
}
