# The bar and panels: the Nusku shell (Quickshell, config/quickshell/nusku: the bar, the quick
# settings panel and the notification pop-ups; it is also the notification server), the
# quick-settings script it calls, and the calendar menu's event helper. The
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
  # The calendar menu's events (scripts/nusku-calendar-events): Python + PyGObject with the GI
  # typelibs it imports (EDataServer, ECal, ICalGLib) on GI_TYPELIB_PATH, no GUI.
  calendarPython = pkgs.python3.withPackages (p: [ p.pygobject3 ]);
  calendarTypelibs = with pkgs; [ glib evolution-data-server libical ];
  nusku-calendar-events = pkgs.stdenv.mkDerivation {
    pname = "nusku-calendar-events";
    version = "1";
    src = ../../scripts/nusku-calendar-events;
    dontUnpack = true;
    nativeBuildInputs = with pkgs; [ wrapGAppsNoGuiHook gobject-introspection ];
    buildInputs = [ calendarPython ] ++ calendarTypelibs;
    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/nusku-calendar-events
      substituteInPlace $out/bin/nusku-calendar-events \
        --replace-fail "#!/usr/bin/env python3" "#!${calendarPython}/bin/python3"
      runHook postInstall
    '';
    # The hook only collects typelibs from the inputs' dev outputs, so they are added here.
    preFixup = ''
      gappsWrapperArgs+=(
        --prefix GI_TYPELIB_PATH : "${lib.makeSearchPath "lib/girepository-1.0" calendarTypelibs}"
      )
    '';
    meta.mainProgram = "nusku-calendar-events";
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
      # Its buttons run commands by name (nusku-quick, nusku-calendar-events, niri, ...).
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.packages = (with pkgs; [
    quickshell # qs: `qs -c nusku ipc call panel toggle` (Super + N), nusku-quick's dnd
    brightnessctl # the panel's brightness slider
    networkmanagerapplet # nm-connection-editor: the Wi-Fi page's "Network settings" (floats)
  ]) ++ [ nusku-quick nusku-calendar-events ];
}
