# The Hyprland desktop at system level: Hyprland (its Lua config is linked by modules/home),
# SDDM with the Catppuccin theme, portals, fonts, Thunar, and Catppuccin for NixOS.
# Ported from nusku-arch packages/base.pacman (Desktop, System, Theming) and lib/system.sh.
{ config, lib, pkgs, ... }:
let
  cfg = config.nusku;
  # nusku-wallpaper copies the chosen wallpaper here; the SDDM theme shows it.
  sddmBgDir = "/var/lib/nusku/sddm-background";
  palette = import ../../lib/palette.nix;
in
{
  # The accent every theming module uses. A bad accent in settings.json is reported by the
  # options.nix assertion; until then "blue" stands in, so catppuccin's own enum type check
  # does not fail first with a less helpful message.
  options.nusku.internal.accent = lib.mkOption {
    type = lib.types.str;
    internal = true;
    readOnly = true;
    default = if builtins.elem cfg.accent palette.accents then cfg.accent else "blue";
  };

  config = {
    catppuccin = {
      enable = true;
      autoEnable = true;
      flavor = "mocha";
      accent = config.nusku.internal.accent;
      sddm = {
        font = "JetBrainsMono Nerd Font";
        background = "${sddmBgDir}/background";
      };
    };

    # Hyprland from the NixOS module: session file, portal, polkit, dconf. No HM hyprland module,
    # which would write ~/.config/hypr/hyprland.conf next to the Lua config.
    programs.hyprland.enable = true;
    # Lock screen (also its PAM service).
    programs.hyprlock.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # SDDM on its default X11 display server, as in nusku-arch (sddm/10-nusku.conf).
    services.xserver.enable = true;
    services.displayManager = {
      defaultSession = "hyprland";
      sddm = {
        enable = true;
        package = pkgs.kdePackages.sddm; # the Qt 6 build the Catppuccin theme needs
      };
    };

    # The greeter background directory belongs to the user, so nusku-wallpaper can write it
    # (nusku-arch sddm_prepare_background_dir). Seeded with the default wallpaper until the
    # first `nusku-wallpaper set`.
    systemd.tmpfiles.rules = [ "d ${sddmBgDir} 0755 ${cfg.user} users -" ];
    system.activationScripts.nusku-sddm-background = {
      deps = [ "users" ];
      text = ''
        mkdir -p ${sddmBgDir}
        chown ${cfg.user}:users ${sddmBgDir}
        chmod 755 ${sddmBgDir}
        if [ ! -e ${sddmBgDir}/background ]; then
          cp ${../../wallpapers/space.png} ${sddmBgDir}/background.png
          chown ${cfg.user}:users ${sddmBgDir}/background.png
          chmod 644 ${sddmBgDir}/background.png
          ln -sfn background.png ${sddmBgDir}/background
        fi
      '';
    };

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
    ];

    programs.thunar = {
      enable = true;
      plugins = [ pkgs.thunar-volman ];
    };
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    services.power-profiles-daemon.enable = true;
    services.udisks2.enable = true;

    environment.systemPackages = with pkgs; [
      qt5.qtwayland
      qt6.qtwayland
      qt6.qtsvg
      qt6.qtdeclarative
    ];
  };
}
