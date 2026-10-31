# Named eval assertions (flake check `eval-desktop`): Home Manager, palette, theme, Hyprland.
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
  "hyprland enabled (NixOS module)" = full.programs.hyprland.enable;
  "home manager: no HM hyprland module (it would write hyprland.conf)" =
    !hm.wayland.windowManager.hyprland.enable;
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
  "portals: hyprland and gtk" =
    full.xdg.portal.enable
    && builtins.any (p: lib.hasPrefix "xdg-desktop-portal-gtk" p.name) full.xdg.portal.extraPortals
    && builtins.any (p: lib.hasPrefix "xdg-desktop-portal-hyprland" p.name) full.xdg.portal.extraPortals;
  "fonts: JetBrainsMono Nerd Font, Noto, Noto emoji" =
    let n = pkgNames full.fonts.packages; in
    builtins.any (lib.hasInfix "jetbrains-mono") n && builtins.elem "noto-fonts" n
    && builtins.elem "noto-fonts-color-emoji" n;
  "hyprlock has a PAM service" = full.security.pam.services ? hyprlock;

  # --- Home Manager: linked configs ------------------------------------------------------------
  "hm: hypr lua files linked" =
    builtins.all (f: hm.xdg.configFile ? "hypr/${f}")
      [ "hyprland.lua" "bindlib.lua" "keybinds.lua" "autostart.lua" "paths.lua" "rules.lua"
        "hyprlock.conf" "hypridle.conf" "hyprpaper.conf" ];
  "hm: keybinds call packaged scripts, not ~/.local/bin" =
    !(has "~/.local/bin" (builtins.readFile hm.xdg.configFile."hypr/keybinds.lua".source))
    && !(has "~/.local/bin" (builtins.readFile hm.xdg.configFile."hypr/autostart.lua".source));
  "hm: autostart starts swaync through systemd" =
    has ''hl.exec_cmd("systemctl --user start swaync")'' (builtins.readFile hm.xdg.configFile."hypr/autostart.lua".source);
  # --- keyboard layout (settings.json "keymap" is an xkb layout) ------------------------------
  "keyboard: the xkb layout reaches X11/SDDM, the console (useXkbConfig) and Hyprland" =
    let gb = (hosts.vm-full.extendModules { modules = [{ nusku.keymap = lib.mkForce "gb"; }]; }).config; in
    gb.services.xserver.xkb.layout == "gb" && gb.console.useXkbConfig
    && cfgText (hmOf gb) "nusku/input.lua" == ''
      -- Nusku keyboard layout (generated from settings.json "keymap"; loaded by ~/.config/hypr/hyprland.lua)
      hl.config({ input = { kb_layout = "gb" } })
    ''
    && full.services.xserver.xkb.layout == "us" && has ''kb_layout = "us"'' (cfgText hm "nusku/input.lua");
  "keyboard: hypr/input.lua no longer fixes the layout; nusku/input.lua loads before local.lua" =
    let main = builtins.readFile ../../config/hypr/hyprland.lua; in
    !(has "kb_layout" (builtins.readFile ../../config/hypr/input.lua))
    # nusku/input appears once, before nusku/local
    && builtins.length (lib.splitString ''paths.nusku .. "/input")''
      (builtins.head (lib.splitString ''paths.nusku .. "/local")'' main))) == 2;
  "hm: gpu.lua at ~/.config/nusku/gpu.lua from the GPU module" =
    cfgText hm "nusku/gpu.lua" == full.nusku.internal.hyprGpuLua;
  "hm: kitty linked, no remembered window size" =
    has "remember_window_size no" (builtins.readFile hm.xdg.configFile."kitty/kitty.conf".source)
    && hm.xdg.configFile ? "kitty/mocha.conf";
  "hm: gtk css imports the rendered theme" =
    has "nusku/theme/gtk.css" hm.gtk.gtk3.extraCss && has "nusku/theme/gtk.css" hm.gtk.gtk4.extraCss;
  "hm: qt5ct/qt6ct linked (kvantum style)" =
    has "style=kvantum" (builtins.readFile hm.xdg.configFile."qt5ct/qt5ct.conf".source)
    && hm.xdg.configFile ? "qt6ct/qt6ct.conf";

  # --- Home Manager: rendered theme ------------------------------------------------------------
  "theme: hypr colours file has the accent (blue)" =
    has ''accent = "rgb(89b4fa)"'' (cfgText hm "nusku/theme/hypr-colors.lua");
  "theme: hypr colours file has the accent (mauve fixture)" =
    has ''accent = "rgb(cba6f7)"'' (cfgText hmM "nusku/theme/hypr-colors.lua");
  "theme: every nusku-arch template rendered to ~/.config/nusku/theme" =
    builtins.all (f: hm.xdg.configFile ? "nusku/theme/${f}")
      [ "colors.css" "colors.rasi" "gtk.css" "hypr-colors.lua" "hypr-cursor.lua"
        "hyprlock-colors.conf" "kitty-accent.conf" "nvim-accent.lua" ];
  "theme: no placeholders left" =
    builtins.all (f: !(has "{{" (cfgText hm "nusku/theme/${f}")))
      [ "colors.css" "colors.rasi" "gtk.css" "hypr-colors.lua" "hypr-cursor.lua"
        "hyprlock-colors.conf" "kitty-accent.conf" "nvim-accent.lua" ];
  "theme: kitty accent and cursor theme" =
    has "cursor #89b4fa" (cfgText hm "nusku/theme/kitty-accent.conf")
    && has ''"catppuccin-mocha-mauve-cursors"'' (cfgText hmM "nusku/theme/hypr-cursor.lua");
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
  "local.lua is not a managed file" = notManaged hm "nusku/local.lua";
  "local.zsh is not a managed file" = notManaged hm "nusku/local.zsh";
  "wallpaper state is not a managed file" =
    notManaged hm ".local/state/nusku/wallpapers" && notManaged hm ".local/state/nusku/current-wallpaper";
  "activation creates local.lua and local.zsh only if missing" =
    has ''[ ! -e "$nuskuDir/local.lua" ]'' (activation hm)
    && has ''[ ! -e "$nuskuDir/local.zsh" ]'' (activation hm);

  # --- scripts and wallpapers ------------------------------------------------------------------
  "scripts: nusku-wallpaper and nusku-menu-wallpaper in the user's packages" =
    let n = pkgNames hm.home.packages; in
    builtins.elem "nusku-wallpaper" n && builtins.elem "nusku-menu-wallpaper" n;
  "wallpapers linked to ~/.local/share/nusku/wallpapers" =
    hm.xdg.dataFile ? "nusku/wallpapers";
}
