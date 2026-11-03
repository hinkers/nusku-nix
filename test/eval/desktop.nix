# Named eval assertions (flake check `eval-desktop`): Home Manager, palette, theme, niri.
{ hosts, lib, ... }:
let
  palette = import ../../lib/palette.nix;
  full = hosts.vm-full.config;
  # The same host with the mauve accent (settings.json is the only source of nusku.accent).
  mauve = (hosts.vm-full.extendModules {
    modules = [{ nusku.accent = lib.mkForce "mauve"; }];
  }).config;
  hmOf = c: c.home-manager.users.${c.nusku.user};
  hm = hmOf full;
  hmM = hmOf mauve;
  has = lib.hasInfix;
  read = builtins.readFile;
  cfgText = h: name: h.xdg.configFile.${name}.text;
  targets = h: map (f: f.target) (builtins.attrValues h.home.file);
  notManaged = h: suffix: !(builtins.any (t: lib.hasSuffix suffix t) (targets h));
  activation = h: lib.concatStrings (map (e: e.data) (builtins.attrValues h.home.activation));
  pkgNames = ps: map (p: p.pname or p.name or "") ps;
  # nusku-arch lib/system.sh papirus_folder_color
  papirusMap = {
    rosewater = "paleorange"; flamingo = "pink"; pink = "magenta"; mauve = "violet";
    red = "red"; maroon = "red"; peach = "orange"; yellow = "yellow"; green = "green";
    teal = "teal"; sky = "cyan"; sapphire = "blue"; blue = "blue"; lavender = "indigo";
  };
in
{
  # --- palette -------------------------------------------------------------------------------
  "palette: mocha values from nusku-arch palette.conf" =
    palette.mocha.blue == "89b4fa" && palette.mocha.mauve == "cba6f7"
    && palette.mocha.crust == "11111b" && builtins.length (builtins.attrNames palette.mocha) == 26;
  "palette: accentHex" = palette.accentHex "blue" == "89b4fa" && palette.accentHex "peach" == "fab387";
  "palette: papirus folder colour for every accent" =
    builtins.all (a: palette.papirusFolder a == papirusMap.${a}) palette.accents
    && builtins.length palette.accents == 14;
  "palette: render fills names, _rgb, accent and accent_name" =
    palette.render "mauve" "#{{accent}} {{accent_rgb}} {{accent_name}} {{base}} {{red_rgb}}"
    == "#cba6f7 203, 166, 247 mauve 1e1e2e 243, 139, 168";
  "palette: render rejects an unknown placeholder" =
    !(builtins.tryEval (palette.render "blue" "{{nope}}")).success;

  # --- NixOS desktop -------------------------------------------------------------------------
  "niri enabled (NixOS module), the default session, no Hyprland" =
    full.programs.niri.enable && full.services.displayManager.defaultSession == "niri"
    && !full.programs.hyprland.enable;
  "niri: GTK file chooser (Thunar, no Nautilus) and xwayland-satellite on PATH" =
    !full.programs.niri.useNautilus
    && builtins.elem "xwayland-satellite" (pkgNames full.environment.systemPackages);
  "sddm: enabled with the catppuccin theme in the accent" =
    full.services.displayManager.sddm.enable
    && full.services.displayManager.sddm.theme == "catppuccin-mocha-blue"
    && mauve.services.displayManager.sddm.theme == "catppuccin-mocha-mauve"
    && full.catppuccin.sddm.font == "JetBrainsMono Nerd Font"
    && full.catppuccin.sddm.background == "/var/lib/nusku/sddm-background/background";
  "sddm: background dir writable by the user, seeded with a default" =
    builtins.any (r: has "/var/lib/nusku/sddm-background 0755 nathan" r) full.systemd.tmpfiles.rules
    && has "if [ ! -e /var/lib/nusku/sddm-background/background ]; then"
      full.system.activationScripts.nusku-sddm-background.text;
  "catppuccin GRUB theme on a grub host (deliberate)" =
    let g = hosts.vm-grub.config; in
    g.catppuccin.grub.enable && g.boot.loader.grub.theme != null
    && has "catppuccin" (toString g.boot.loader.grub.theme);
  "catppuccin TTY colours (deliberate)" =
    let m = hosts.vm-min.config; in
    m.catppuccin.tty.enable && builtins.length m.console.colors == 16;
  "catppuccin mocha + accent on NixOS and HM" =
    full.catppuccin.enable && full.catppuccin.flavor == "mocha" && full.catppuccin.accent == "blue"
    && hm.catppuccin.enable && hm.catppuccin.flavor == "mocha" && hm.catppuccin.accent == "blue"
    && hmM.catppuccin.accent == "mauve";
  "portals: gnome (screencasting) and gtk" =
    full.xdg.portal.enable
    && builtins.any (p: lib.hasPrefix "xdg-desktop-portal-gtk" p.name) full.xdg.portal.extraPortals
    && builtins.any (p: lib.hasPrefix "xdg-desktop-portal-gnome" p.name) full.xdg.portal.extraPortals;
  "fonts: JetBrainsMono Nerd Font, Noto, Noto emoji" =
    let n = pkgNames full.fonts.packages; in
    builtins.any (lib.hasInfix "jetbrains-mono") n && builtins.elem "noto-fonts" n
    && builtins.elem "noto-fonts-color-emoji" n;
  "hyprlock enabled, with its PAM service" =
    full.programs.hyprlock.enable && full.security.pam.services ? hyprlock;

  # --- Home Manager: linked configs ------------------------------------------------------------
  "hm: niri config and both bind layouts linked; config.kdl checked by niri validate" =
    builtins.all (f: hm.xdg.configFile ? "niri/${f}") [ "config.kdl" "binds-niri.kdl" "binds-nusku.kdl" ]
    && lib.hasPrefix "niri-config.kdl" hm.xdg.configFile."niri/config.kdl".source.name;
  "niri: Nusku's binds in use, every Nix-written file included, local.kdl last and optional" =
    let main = read ../../config/niri/config.kdl; in
    has ''include "binds-nusku.kdl"'' main && !(has ''include "binds-niri.kdl"'' main)
    && builtins.all (f: has ''include "../nusku/${f}"'' main)
      [ "theme/niri-colors.kdl" "gpu.kdl" "input.kdl" "apps.kdl" ]
    && lib.hasSuffix ''include optional=true "../nusku/local.kdl"'' (lib.trim main);
  "niri: binds and startup call packaged commands, not ~/.local/bin" =
    builtins.all (f: !(has "~/.local/bin" (read (../../config/niri + "/${f}"))))
      [ "config.kdl" "binds-niri.kdl" "binds-nusku.kdl" ];
  "niri: kitty blurred, apps.kdl always written" =
    has "background-effect" (read ../../config/niri/config.kdl)
    && has "Nusku: startup commands and binds" (cfgText hm "nusku/apps.kdl");
  "session services: the Nusku shell, swayidle and polkit-gnome start with the session" =
    hm.systemd.user.services ? nusku-shell && hm.services.swayidle.enable && hm.services.polkit-gnome.enable
    && !(hm.services.hyprpolkitagent.enable or false);
  "lock screen: hyprlock.conf linked (wallpaper, palette colours); swayidle locks with hyprlock" =
    hm.xdg.configFile."hypr/hyprlock.conf".source == ../../config/hypr/hyprlock.conf
    && has "current-wallpaper" (read ../../config/hypr/hyprlock.conf)
    && has "hyprlock-colors.conf" (read ../../config/hypr/hyprlock.conf)
    && has "pidof hyprlock || " hm.services.swayidle.events.lock
    && !(hm.programs.swaylock.enable or false);
  # --- keyboard layout (settings.json "keymap" is an xkb layout) ------------------------------
  "keyboard: the xkb layout reaches X11/SDDM, the console (useXkbConfig) and niri" =
    let gb = (hosts.vm-full.extendModules { modules = [{ nusku.keymap = lib.mkForce "gb"; }]; }).config; in
    gb.services.xserver.xkb.layout == "gb" && gb.console.useXkbConfig
    && has ''layout "gb"'' (cfgText (hmOf gb) "nusku/input.kdl")
    && full.services.xserver.xkb.layout == "us" && has ''layout "us"'' (cfgText hm "nusku/input.kdl");
  "keyboard: config.kdl doesn't fix the layout; nusku/input.kdl is included before local.kdl" =
    let main = read ../../config/niri/config.kdl; in
    !(has "layout \"" main)
    && builtins.length (lib.splitString ''include "../nusku/input.kdl"''
      (builtins.head (lib.splitString ''include optional=true "../nusku/local.kdl"'' main))) == 2;
  "hm: gpu.kdl at ~/.config/nusku/gpu.kdl from the GPU module" =
    cfgText hm "nusku/gpu.kdl" == full.nusku.internal.niriGpuKdl;
  "hm: kitty linked, no remembered window size, semi-transparent" =
    has "remember_window_size no" (builtins.readFile hm.xdg.configFile."kitty/kitty.conf".source)
    && has "background_opacity 0.85" (builtins.readFile hm.xdg.configFile."kitty/kitty.conf".source)
    && hm.xdg.configFile ? "kitty/mocha.conf";
  "hm: gtk css imports the rendered theme" =
    has "nusku/theme/gtk.css" hm.gtk.gtk3.extraCss && has "nusku/theme/gtk.css" hm.gtk.gtk4.extraCss;
  "hm: qt5ct/qt6ct linked (kvantum style)" =
    has "style=kvantum" (builtins.readFile hm.xdg.configFile."qt5ct/qt5ct.conf".source)
    && hm.xdg.configFile ? "qt6ct/qt6ct.conf";

  # --- Home Manager: rendered theme ------------------------------------------------------------
  "theme: niri colours file has the accent (blue)" =
    has ''active-color "#89b4fa"'' (cfgText hm "nusku/theme/niri-colors.kdl");
  "theme: niri colours file has the accent (mauve fixture)" =
    has ''active-color "#cba6f7"'' (cfgText hmM "nusku/theme/niri-colors.kdl");
  "theme: every nusku-arch template rendered to ~/.config/nusku/theme" =
    builtins.all (f: hm.xdg.configFile ? "nusku/theme/${f}")
      [ "colors.css" "colors.rasi" "gtk.css" "niri-colors.kdl" "hyprlock-colors.conf" "kitty-accent.conf" "nvim-accent.lua" ];
  "theme: no placeholders left" =
    builtins.all (f: !(has "{{" (cfgText hm "nusku/theme/${f}")))
      [ "colors.css" "colors.rasi" "gtk.css" "niri-colors.kdl" "hyprlock-colors.conf" "kitty-accent.conf" "nvim-accent.lua" ];
  "theme: kitty accent and cursor theme" =
    has "cursor #89b4fa" (cfgText hm "nusku/theme/kitty-accent.conf")
    && has ''"catppuccin-mocha-mauve-cursors"'' (cfgText hmM "nusku/theme/niri-colors.kdl");
  "theme: catppuccin cursors in the accent" =
    hm.home.pointerCursor.name == "catppuccin-mocha-blue-cursors"
    && hmM.home.pointerCursor.name == "catppuccin-mocha-mauve-cursors"
    && hm.home.pointerCursor.size == 24;
  "theme: gtk adw-gtk3-dark, Papirus-Dark, Noto Sans 11" =
    hm.gtk.enable && hm.gtk.theme.name == "adw-gtk3-dark" && hm.gtk.iconTheme.name == "Papirus-Dark"
    && hm.gtk.font.name == "Noto Sans" && hm.gtk.font.size == 11;
  "theme: papirus folders blue for accent blue" =
    has "-C blue" hm.gtk.iconTheme.package.installPhase;
  "theme: papirus folders violet for accent mauve" =
    has "-C violet" hmM.gtk.iconTheme.package.installPhase;
  "theme: kvantum catppuccin in the accent via qtct" =
    hm.qt.enable && hm.qt.style.name == "kvantum" && hm.qt.platformTheme.name == "qtct"
    && has "theme=catppuccin-mocha-blue" (cfgText hm "Kvantum/kvantum.kvconfig");

  # --- user files survive rebuilds -----------------------------------------------------------
  "local.kdl is not a managed file" = notManaged hm "nusku/local.kdl";
  "local.zsh is not a managed file" = notManaged hm "nusku/local.zsh";
  "wallpaper state is not a managed file" =
    notManaged hm ".local/state/nusku/wallpapers" && notManaged hm ".local/state/nusku/current-wallpaper";
  "activation creates local.kdl and local.zsh only if missing" =
    has ''[ ! -e "$nuskuDir/local.kdl" ]'' (activation hm)
    && has ''[ ! -e "$nuskuDir/local.zsh" ]'' (activation hm);

  # --- scripts and wallpapers ------------------------------------------------------------------
  "scripts: nusku-wallpaper and nusku-menu-wallpaper in the user's packages" =
    let n = pkgNames hm.home.packages; in
    builtins.elem "nusku-wallpaper" n && builtins.elem "nusku-menu-wallpaper" n;
  "wallpapers linked to ~/.local/share/nusku/wallpapers" =
    hm.xdg.dataFile ? "nusku/wallpapers";
}
