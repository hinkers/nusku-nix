-- Nusku - session autostart (runs once when Hyprland starts, not on config reloads).
-- Commands come from the user's Nix profile (Home Manager), not a bin directory in $HOME.

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("nusku-wallpaper restore")
    hl.exec_cmd("waybar")
    -- Through systemd: D-Bus activation also starts this unit, so a bare "swaync" would race it.
    hl.exec_cmd("systemctl --user start swaync")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
