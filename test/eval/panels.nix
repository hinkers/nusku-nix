# Named eval assertions (flake check `eval-panels`): the Nusku shell (Quickshell: bar, quick
# settings, notifications), the quick-settings scripts and the drop-down calendar.
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
  calendar = pkgByName "nusku-calendar";
  layerShell = pkgs.gtk4-layer-shell; # same nixpkgs input as the hosts
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
    && shell.Unit.X-Restart-Triggers != [ ];
  "shell: Waybar and swaync are gone" =
    !(hm.services.swaync.enable or false) && !hm.programs.waybar.enable
    && !(builtins.elem "waybar" pkgNames) && !(hm.xdg.configFile ? "waybar/config.jsonc")
    && !(has "waybar" (builtins.readFile ../../config/niri/config.kdl));
  "shell: UPower on (the bar's battery)" = full.services.upower.enable;
  "shell: Super + N and the bar pill open the panel; scripts called by name, no ~/.local/bin" =
    builtins.all (f: has ''"qs" "-c" "nusku" "ipc" "call" "panel" "toggle"'' (builtins.readFile (../../config/niri + "/${f}")))
      [ "binds-niri.kdl" "binds-nusku.kdl" ]
    && has "PanelState.toggleOn(pill.screen)" (qml "bar/QuickPill.qml")
    && builtins.all (f: !(has ".local/bin" (builtins.readFile f))) qmlFiles
    && has ''"nusku-calendar"'' (qml "bar/Clock.qml")
    && has ''"nusku-menu-wifi"'' (qml "panel/QuickSettings.qml") && has ''"nusku-menu-power"'' (qml "panel/QuickSettings.qml");
  "shell: it is the notification server, with Do Not Disturb over IPC" =
    has "NotificationServer" (qml "services/Notifs.qml")
    && has "function toggleDnd" (qml "services/Notifs.qml")
    && has "qs -c nusku ipc call notifications" (scriptText "nusku-quick");

  # --- scripts -------------------------------------------------------------------------------
  "scripts: quick settings and pickers installed" =
    builtins.all (n: pkgByName n != null)
      [ "nusku-quick" "nusku-menu-wifi" "nusku-menu-bluetooth" "nusku-calendar" ];
  "scripts: runtime tools on their PATH" =
    let
      q = scriptText "nusku-quick";
      w = scriptText "nusku-menu-wifi";
      b = scriptText "nusku-menu-bluetooth";
    in
    builtins.all (p: has p q) [ "wlsunset" "wireplumber" "networkmanager" "bluez" "power-profiles-daemon" "quickshell" "procps" "util-linux" "libnotify" ]
    && builtins.all (p: has p w) [ "rofi" "networkmanager" "kitty" "libnotify" ]
    && builtins.all (p: has p b) [ "rofi" "bluez" "blueman" "util-linux" ];
  "scripts: own set options kept (no added errexit)" =
    !(has "set -o errexit" (scriptText "nusku-quick")) && has "set -uo pipefail" (scriptText "nusku-quick");
  "nm-connection-editor installed" = builtins.elem "network-manager-applet" pkgNames;

  # --- calendar ------------------------------------------------------------------------------
  "calendar: wrapper preloads gtk4-layer-shell from the store" =
    calendar != null
    && builtins.any (p: (p.pname or "") == "gtk4-layer-shell") calendar.buildInputs
    && has (builtins.unsafeDiscardStringContext "${layerShell}/lib/libgtk4-layer-shell.so") calendar.preFixup
    # typelibs the hook misses (it sees only the dev outputs)
    && builtins.all (p: has (builtins.unsafeDiscardStringContext "${p}/lib/girepository-1.0") calendar.preFixup)
      [ pkgs.gtk4-layer-shell pkgs.evolution-data-server pkgs.libical ];
  "calendar: python with pygobject; GI typelibs from gtk4, layer shell, EDS, libical" =
    let names = map (p: p.pname or p.name or "") calendar.buildInputs; in
    builtins.all (n: builtins.elem n names)
      [ "gtk4" "gtk4-layer-shell" "evolution-data-server" "libical" ]
    && builtins.any (p: builtins.any (m: has "pygobject" (m.name or "")) (p.paths or [ ])) calendar.buildInputs;
  "calendar: evolution-data-server and online accounts on the host" =
    full.services.gnome.evolution-data-server.enable
    && full.services.gnome.gnome-online-accounts.enable;

  # The panel's buttons run commands by name (nusku-menu-power, niri, ...); the shell is a
  # systemd user unit, so it gets the user's profile on PATH itself rather than relying on what
  # niri-session imports into the user manager.
  "shell: the user's profile is on the unit's PATH" =
    has "PATH=/etc/profiles/per-user/nathan/bin:" (toString shell.Service.Environment);
}
