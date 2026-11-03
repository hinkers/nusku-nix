# Catppuccin Mocha + the host's accent for everything that is not a single app's config:
#  - nusku-arch theme/templates/*.tmpl rendered to ~/.config/nusku/theme/<name> (the paths
#    Nusku's configs read: niri colours/cursor, hyprlock colours, kitty accent, colors.css,
#    gtk.css, nvim-accent.lua, and the shell's Colors.qml);
#  - GTK: adw-gtk3-dark + Papirus-Dark (folders in the accent colour) + Noto Sans 11, with the
#    rendered gtk.css on top (nusku-arch settings.ini templates and config/gtk-*/gtk.css);
#  - Qt: qt5ct/qt6ct (nusku-arch files) with the Kvantum style, Catppuccin Kvantum via catppuccin/nix;
#  - Catppuccin cursors in the accent via catppuccin/nix.
{ osConfig, config, lib, pkgs, ... }:
let
  palette = import ../../lib/palette.nix;
  accent = osConfig.nusku.internal.accent;
  templates = ../../theme/templates;
  rendered = lib.mapAttrs'
    (file: _: lib.nameValuePair "nusku/theme/${lib.removeSuffix ".tmpl" file}" {
      text = palette.renderFile accent (templates + "/${file}");
    })
    (lib.filterAttrs (f: t: t == "regular" && lib.hasSuffix ".tmpl" f) (builtins.readDir templates));
  papirus = pkgs.papirus-icon-theme.override { color = palette.papirusFolder accent; };
in
{
  xdg.configFile = rendered // {
    "qt5ct/qt5ct.conf".source = ../../config/qt5ct/qt5ct.conf;
    "qt6ct/qt6ct.conf".source = ../../config/qt6ct/qt6ct.conf;
  };

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = papirus;
    };
    font = {
      name = "Noto Sans";
      size = 11;
    };
    colorScheme = "dark";
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
    # Relative imports: resolved from ~/.config/gtk-*/gtk.css to ~/.config/nusku/theme/gtk.css.
    gtk3.extraCss = builtins.readFile ../../config/gtk-3.0/gtk.css;
    gtk4.extraCss = builtins.readFile ../../config/gtk-4.0/gtk.css;
  };
  # Our own Papirus build (nusku-arch's folder colour map), not catppuccin's papirus-folders.
  catppuccin.gtk.icon.enable = false;

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };
  # catppuccin.kvantum is auto-enabled (qt.enable): theme catppuccin-mocha-<accent>.

  catppuccin.cursors.enable = true;
  home.pointerCursor = {
    enable = true;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
