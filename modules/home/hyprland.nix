# The Hyprland desktop for the user: nusku-arch's Lua config and Kitty linked from config/,
# the GPU/monitor Lua from modules/nixos/gpu.nix, the session tools autostart.lua runs,
# the wallpapers and the wallpaper scripts, and the user's own files (created once, never managed).
{ osConfig, config, lib, pkgs, ... }:
let
  scripts = import ../../lib/scripts.nix { inherit pkgs lib; };
  hyprctl = osConfig.programs.hyprland.package; # the same Hyprland the session runs

  # Every regular file under `dir` as xdg.configFile."<prefix>/<relative path>" (one entry per
  # file, so other modules can add files to the same directory).
  linkTree = prefix: dir:
    lib.listToAttrs (map
      (path:
        let rel = lib.removePrefix (toString dir + "/") (toString path); in
        lib.nameValuePair "${prefix}/${rel}" { source = path; })
      (lib.filesystem.listFilesRecursive dir));

  nusku-wallpaper = scripts.mkScript {
    name = "nusku-wallpaper";
    deps = with pkgs; [ coreutils jq procps util-linux swaybg hyprctl ];
  };
  nusku-menu-wallpaper = scripts.mkScript {
    name = "nusku-menu-wallpaper";
    deps = with pkgs; [ coreutils jq rofi hyprctl nusku-wallpaper ];
  };

  # The user's own files: written once from these templates, never touched again.
  localLua = pkgs.writeText "local.lua" ''
    -- Your own Hyprland settings (Lua). Nusku never overwrites this file.
    -- It is loaded last by ~/.config/hypr/hyprland.lua, so anything here wins.
    -- Syntax: https://wiki.hypr.land/Configuring/  Examples:
    --   hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1 })
    --   hl.config({ input = { kb_layout = "us,de", kb_options = "grp:alt_shift_toggle" } })
    --   hl.bind("SUPER + D", hl.dsp.exec_cmd("discord"))
  '';
  localZsh = pkgs.writeText "local.zsh" ''
    # Your own zsh settings. Nusku never overwrites this file.
    # It is sourced last by ~/.zshrc, so anything here wins. Examples:
    #   alias ll='eza -la'
    #   export EDITOR=nvim
    #   path+=("$HOME/bin")
  '';
in
{
  xdg.configFile = linkTree "hypr" ../../config/hypr // linkTree "kitty" ../../config/kitty // {
    # nusku-arch's hyprland.lua loads <config>/nusku/gpu.lua (paths.nusku) when present.
    "nusku/gpu.lua".text = osConfig.nusku.internal.hyprGpuLua;
    # Sunshine (modules/nixos/apps.nix): its user unit is WantedBy graphical-session.target,
    # which nothing reaches here (Hyprland runs without UWSM), so the session starts it. The
    # file is types.lines: other picks (Obsidian, browsers.nix) add their own block.
    "nusku/autostart.lua" = lib.mkIf (builtins.elem "sunshine" osConfig.nusku.apps) {
      text = ''
        -- Sunshine: the game-streaming host (modules/home/hyprland.nix).
        hl.on("hyprland.start", function()
            hl.exec_cmd("systemctl --user start sunshine")
        end)
      '';
    };
  };

  # A stable path for the wallpapers: nusku-wallpaper saves choices under it.
  xdg.dataFile."nusku/wallpapers".source = ../../wallpapers;

  home.packages = (with pkgs; [
    kitty
    hyprpaper
    hypridle
    hyprshot
    grim
    slurp
    wl-clipboard
    cliphist
    swaybg # nusku-wallpaper's fallback where hyprpaper cannot start (Hyper-V)
    brightnessctl
    playerctl
    pavucontrol
    libnotify
    jq
    imagemagick
    xdg-user-dirs
  ]) ++ [ nusku-wallpaper nusku-menu-wallpaper ];

  # autostart.lua runs `systemctl --user start hyprpolkitagent`.
  services.hyprpolkitagent.enable = true;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # local.lua / local.zsh: created only if missing (nusku-arch hypr_write_local_lua). They and
  # the wallpaper state (~/.local/state/nusku) are never in home.file, so rebuilds keep them.
  home.activation.nuskuLocalFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    nuskuDir="${config.xdg.configHome}/nusku"
    run mkdir -p "$nuskuDir" "${config.home.homeDirectory}/Pictures/Screenshots"
    if [ ! -e "$nuskuDir/local.lua" ]; then
      run install -m 644 ${localLua} "$nuskuDir/local.lua"
    fi
    if [ ! -e "$nuskuDir/local.zsh" ]; then
      run install -m 644 ${localZsh} "$nuskuDir/local.zsh"
    fi
  '';
}
