# Named eval assertions (flake check `eval-panels`): the Nusku shell (Quickshell: bar, quick
# settings, notifications, calendar, launcher, power menu), the quick-settings scripts and the
# calendar's event helper.
{ hosts, lib, pkgs, ... }:
let
  full = hosts.vm-full.config;
  hm = full.home-manager.users.${full.nusku.user};
  has = lib.hasInfix;
  cfgFile = name: hm.xdg.configFile.${name};
  pkgByName = n: lib.findFirst (p: (p.pname or p.name or "") == n) null hm.home.packages;
  pkgNames = map (p: p.pname or p.name or "") hm.home.packages;
  # writeShellApplication's text attribute (the file it writes): no build, no IFD.
  scriptText = n: (pkgByName n).text;
  shell = hm.systemd.user.services.nusku-shell;
  qml = f: builtins.readFile (../../config/quickshell/nusku + "/${f}");
  qmlFiles = map toString (lib.filesystem.listFilesRecursive ../../config/quickshell/nusku);
  calendar = pkgByName "nusku-calendar-events";
in
{
  # --- The Nusku shell (Quickshell) -------------------------------------------------------
  "shell: every QML file linked to ~/.config/quickshell/nusku, with the generated Colors.qml" =
    builtins.all (f: hm.xdg.configFile ? "quickshell/nusku/${lib.removePrefix (toString ../../config/quickshell/nusku + "/") f}") qmlFiles
    && has ''"#89b4fa"'' (cfgFile "quickshell/nusku/Colors.qml").text
    && has "pragma Singleton" (cfgFile "quickshell/nusku/Colors.qml").text;
  "shell: user service started with the session, restarted on a change" =
    has "/bin/qs -c nusku" (toString shell.Service.ExecStart)
    && builtins.elem "graphical-session.target" shell.Install.WantedBy
    && builtins.elem "graphical-session.target" shell.Unit.PartOf
    && shell.Unit.X-Restart-Triggers != [ ]
    # a newline in any value breaks the unit file (sd-switch can't load it)
    && builtins.all (v: !(has "\n" (toString v))) (lib.flatten (map builtins.attrValues [ shell.Unit shell.Service shell.Install ]));
  "shell: Waybar and swaync are gone" =
    !(hm.services.swaync.enable or false) && !hm.programs.waybar.enable
    && !(builtins.elem "waybar" pkgNames) && !(hm.xdg.configFile ? "waybar/config.jsonc")
    && !(has "waybar" (builtins.readFile ../../config/niri/config.kdl));
  "shell: UPower on (the bar's battery)" = full.services.upower.enable;
  "shell: the bar's speaker: scroll for volume, middle-click mute, click for the volume menu" =
    has "Audio.nudge" (qml "bar/Volume.qml") && has "Audio.toggleMute" (qml "bar/Volume.qml")
    && has "Menus.volume.toggleAt" (qml "bar/Volume.qml")
    && has "preferredDefaultAudioSink" (qml "menus/VolumeMenu.qml") && has "Audio.streams" (qml "menus/VolumeMenu.qml")
    && has "PwNodeType.AudioOutStream" (qml "services/Audio.qml");
  "shell: a click on the battery opens its details under it" =
    has "Menus.battery.toggleAt" (qml "bar/Battery.qml")
    && has "edge: \"top\"" (qml "menus/BatteryMenu.qml") && has "healthPercentage" (qml "menus/BatteryMenu.qml")
    && has "BatteryMenu {}" (qml "shell.qml");
  "shell: no Wi-Fi or Bluetooth tray icons, but blueman-applet still runs (the Bluetooth agent)" =
    has "Hidden=true" (cfgFile "autostart/nm-applet.desktop").text
    && !(hm.xdg.configFile ? "autostart/blueman.desktop")
    # (dconf values are typed GVariants by now: compare the strings inside)
    && map (v: v.value) hm.dconf.settings."org/blueman/general".plugin-list.value == [ "!StatusIcon" ]
    && full.services.blueman.enable;
  "shell: Super + N and the bar pill open the panel; scripts called by name, no ~/.local/bin" =
    builtins.all (f: has ''"qs" "-c" "nusku" "ipc" "call" "panel" "toggle"'' (builtins.readFile (../../config/niri + "/${f}")))
      [ "binds-niri.kdl" "binds-nusku.kdl" ]
    && has "PanelState.toggleOn(pill.screen)" (qml "bar/QuickPill.qml")
    && builtins.all (f: !(has ".local/bin" (builtins.readFile f))) qmlFiles
    && has "Menus.calendar.toggleOn(root.screen)" (qml "bar/Clock.qml")
    && has ''PanelState.page = "wifi"'' (qml "panel/QuickSettings.qml")
    && has ''PanelState.openPage(pill.screen, "bluetooth")'' (qml "bar/QuickPill.qml")
    && has "Menus.launcher.toggleOn(root.screen)" (qml "bar/LauncherButton.qml")
    && has "Menus.media.toggleAt" (qml "bar/MediaButton.qml");
  "shell: quick settings is Wi-Fi, Bluetooth, four labelled toggles, brightness, notifications" =
    let q = qml "panel/QuickSettings.qml"; in
    builtins.all (t: has ''title: "${t}"'' q) [ "Do Not Disturb" "Night light" "Airplane mode" "Keep awake" ]
    && has "ToggleTile" (qml "panel/ToggleTile.qml" + q) && has "Brightness.set" q
    && !(has "PowerProfiles" q) && !(has "Pipewire" q) && !(has "screenshot" q);
  "shell: media menu (track, seek, controls, player choice) and collapsible audio pickers" =
    has "Media.pickedName" (qml "menus/MediaMenu.qml") && has "canSeek" (qml "menus/MediaMenu.qml")
    && has "component DevicePicker" (qml "menus/VolumeMenu.qml") && has "property bool expanded: false" (qml "menus/VolumeMenu.qml");
  "shell: launcher (Super + Space / Super + D) and power menu (Super + Escape / Super + X) are its own" =
    let nusku = builtins.readFile ../../config/niri/binds-nusku.kdl; niri = builtins.readFile ../../config/niri/binds-niri.kdl; ipc = n: ''"qs" "-c" "nusku" "ipc" "call" "${n}" "toggle"''; in
    has ("Mod+Space hotkey-overlay-title=\"App launcher\" { spawn " + ipc "launcher") nusku
    && has ("Mod+Escape hotkey-overlay-title=\"Power menu\" { spawn " + ipc "session") nusku
    && has ("Mod+D hotkey-overlay-title=\"Run an Application\" { spawn " + ipc "launcher") niri
    && has ("Mod+X hotkey-overlay-title=\"Power menu\" { spawn " + ipc "session") niri
    && !(has "drun" nusku) && !(has "drun" niri) && !(has "nusku-menu-power" (nusku + niri));
  "shell: the volume / brightness pop-up, and the brightness keys show it" =
    has "edge: \"right\"" (qml "frame/Osd.qml") && has "onVolumeChanged" (qml "frame/Osd.qml")
    && builtins.all (f: has "qs -c nusku ipc call osd brightness" (builtins.readFile (../../config/niri + "/${f}")))
      [ "binds-niri.kdl" "binds-nusku.kdl" ];
  "shell: Wi-Fi and Bluetooth pages in quick settings (native NetworkManager / BlueZ)" =
    has "connectWithPsk" (qml "panel/WifiPage.qml") && has "scannerEnabled" (qml "panel/WifiPage.qml")
    && has "d.pair()" (qml "panel/BluetoothPage.qml") && has "discovering" (qml "panel/BluetoothPage.qml");
  "shell: every menu grows out of the frame (drawers) and one is open at a time" =
    builtins.all (f: has "Drawer {" (qml "menus/${f}")) [ "Calendar.qml" "Launcher.qml" "Session.qml" "Wallpaper.qml" "PickerMenu.qml" ]
    && builtins.all (f: has "PickerMenu {" (qml "menus/${f}")) [ "Clipboard.qml" "Keybinds.qml" ]
    && has "edge: \"top\"" (qml "menus/Calendar.qml") && has "edge: \"top\"" (qml "menus/Launcher.qml")
    && has "edge: \"right\"" (qml "menus/Session.qml")
    && has "function closeAll" (qml "services/Menus.qml");
  "shell: it is the notification server, with Do Not Disturb over IPC" =
    has "NotificationServer" (qml "services/Notifs.qml")
    && has "function toggleDnd" (qml "services/Notifs.qml")
    && has "qs -c nusku ipc call notifications" (scriptText "nusku-quick");

  # --- scripts -------------------------------------------------------------------------------
  "scripts: quick settings and pickers installed" =
    builtins.all (n: pkgByName n != null)
      [ "nusku-quick" "nusku-calendar-events" ];
  "scripts: runtime tools on their PATH" =
    let q = scriptText "nusku-quick"; in
    builtins.all (p: has p q) [ "wlsunset" "wireplumber" "networkmanager" "bluez" "power-profiles-daemon" "quickshell" "procps" "util-linux" "libnotify" ];
  "scripts: own set options kept (no added errexit)" =
    !(has "set -o errexit" (scriptText "nusku-quick")) && has "set -uo pipefail" (scriptText "nusku-quick");
  "nm-connection-editor installed" = builtins.elem "network-manager-applet" pkgNames;

  # --- calendar ------------------------------------------------------------------------------
  "calendar: the event helper has pygobject and the EDS, ECal and libical typelibs (no GUI)" =
    let names = map (p: p.pname or p.name or "") calendar.buildInputs; in
    calendar != null
    && builtins.all (n: builtins.elem n names) [ "evolution-data-server" "libical" ]
    && !(builtins.elem "gtk4" names) && !(builtins.elem "gtk4-layer-shell" names)
    && builtins.any (p: builtins.any (m: has "pygobject" (m.name or "")) (p.paths or [ ])) calendar.buildInputs
    && builtins.all (p: has (builtins.unsafeDiscardStringContext "${p}/lib/girepository-1.0") calendar.preFixup)
      [ pkgs.evolution-data-server pkgs.libical ];
  "calendar: evolution-data-server and online accounts on the host" =
    full.services.gnome.evolution-data-server.enable
    && full.services.gnome.gnome-online-accounts.enable;

  # The panel's buttons run commands by name (nusku-quick, niri, ...); the shell is a
  # systemd user unit, so it gets the user's profile on PATH itself rather than relying on what
  # niri-session imports into the user manager.
  "shell: the user's profile is on the unit's PATH" =
    has "PATH=/etc/profiles/per-user/nathan/bin:" (toString shell.Service.Environment);
}
