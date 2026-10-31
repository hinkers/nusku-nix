# Named eval assertions (flake check `eval-panels`): Waybar, the swaync quick-settings panel,
# the quick-settings scripts and the drop-down calendar.
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
  swaync = hm.systemd.user.services.swaync;
  calendar = pkgByName "nusku-calendar";
  layerShell = pkgs.gtk4-layer-shell; # same nixpkgs input as the hosts
in
{
  # --- Waybar --------------------------------------------------------------------------------
  "waybar: nusku-arch config and style linked" =
    (cfgFile "waybar/config.jsonc").source == ../../config/waybar/config.jsonc
    && (cfgFile "waybar/style.css").source == ../../config/waybar/style.css;
  "waybar: package installed (autostart.lua runs it)" = builtins.elem "waybar" pkgNames;
  "waybar: own style, not catppuccin's (palette comes from nusku/theme/colors.css)" =
    !hm.catppuccin.waybar.enable && !hm.programs.waybar.enable
    && has "../nusku/theme/colors.css" (builtins.readFile ../../config/waybar/style.css);
  "waybar: scripts called by name, no ~/.local/bin" =
    let t = builtins.readFile ../../config/waybar/config.jsonc; in
    !(has ".local/bin" t) && has ''"on-click": "nusku-calendar"'' t
    && has ''"on-click-right": "nusku-menu-wifi"'' t && has ''"on-click-right": "nusku-menu-bluetooth"'' t;
  "waybar: one quick-settings pill, no volume module" =
    let t = builtins.readFile ../../config/waybar/config.jsonc; in
    has ''"group/quick"'' t && !(has "pulseaudio" t) && !(has "wireplumber" t);

  # --- swaync --------------------------------------------------------------------------------
  "swaync: HM service, nusku-arch style linked, catppuccin's off" =
    hm.services.swaync.enable && !hm.catppuccin.swaync.enable
    && (cfgFile "swaync/style.css").source == ../../config/swaync/style.css;
  "swaync: config.json is written per machine, not by Home Manager" =
    !(cfgFile "swaync/config.json").enable;
  "swaync: unit writes config.json from the template before starting" =
    let pre = toString swaync.Service.ExecStartPre; in
    has "/bin/nusku-swaync-config" pre
    && has "config.template.json" pre
    && has "${hm.xdg.configHome}/swaync/config.json" pre
    && lib.hasPrefix "-" pre; # a failure must not stop notifications
  "swaync: unit restarts when the template changes" =
    builtins.any (has "config.template.json") (map toString swaync.Unit.X-Restart-Triggers);
  "swaync: template is nusku-arch's with scripts by name" =
    let t = builtins.readFile ../../config/swaync/config.template.json; in
    !(has ".local/bin" t) && has ''"nusku-quick toggle night"'' t && has ''nusku-menu-wifi"'' t
    && has "show-per-app" t;

  # --- scripts -------------------------------------------------------------------------------
  "scripts: quick settings and pickers installed" =
    builtins.all (n: pkgByName n != null)
      [ "nusku-quick" "nusku-menu-wifi" "nusku-menu-bluetooth" "nusku-calendar" "nusku-swaync-config" ];
  "scripts: runtime tools on their PATH" =
    let
      q = scriptText "nusku-quick";
      w = scriptText "nusku-menu-wifi";
      b = scriptText "nusku-menu-bluetooth";
    in
    builtins.all (p: has p q) [ "hyprsunset" "hypridle" "wireplumber" "networkmanager" "bluez" "power-profiles-daemon" "SwayNotificationCenter" "procps" "util-linux" "libnotify" ]
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

  # The panel's buttons run commands by name (nusku-menu-power, hyprshot, ...); swaync is a
  # systemd user unit, so it gets the user's profile on PATH itself rather than relying on what
  # Hyprland imports into the user manager.
  "swaync: the user's profile is on the unit's PATH" =
    has "PATH=/etc/profiles/per-user/nathan/bin:" (toString swaync.Service.Environment);
}
