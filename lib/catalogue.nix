# The optional app and language catalogue: pure data (no pkgs), read by the NixOS modules and
# by the installer (`nix eval --json .#lib.catalogue`). Groups, ids, labels and ★ defaults are
# nusku-arch's packages/apps.list, minus what Nix can't or won't install (Zen Browser, UFW,
# Flatpak, and the four ArtCraft apps nixpkgs lacks). modules/nixos/apps.nix installs them.
#   groups: { id; label; }
#   apps:   { id; group; label; star ? false (pre-selected); btrfs ? false (only offered when
#             /home is btrfs); browser ? false (a web browser: the first picked one opens links) }
#   langs:  { id; label; }
{
  groups = [
    { id = "dev"; label = "Dev"; }
    { id = "everyday"; label = "Everyday"; }
    { id = "media"; label = "Media"; }
    { id = "creative"; label = "Creative"; }
    { id = "artcraft"; label = "ArtCraft"; }
    { id = "gaming"; label = "Gaming"; }
    { id = "system"; label = "System tools"; }
  ];

  apps = [
    { id = "neovim"; group = "dev"; label = "Neovim (LazyVim)"; star = true; }
    { id = "gh"; group = "dev"; label = "GitHub CLI"; star = true; }
    { id = "claude-code"; group = "dev"; label = "Claude Code"; star = true; }
    { id = "lazygit"; group = "dev"; label = "lazygit"; }
    { id = "docker"; group = "dev"; label = "Docker + Compose"; }
    { id = "vscode"; group = "dev"; label = "VS Code"; }

    { id = "firefox"; group = "everyday"; label = "Firefox"; star = true; browser = true; }
    { id = "chromium"; group = "everyday"; label = "Chromium"; browser = true; }
    { id = "brave"; group = "everyday"; label = "Brave"; browser = true; }
    { id = "librewolf"; group = "everyday"; label = "LibreWolf"; browser = true; }
    { id = "discord"; group = "everyday"; label = "Discord"; star = true; }
    { id = "obsidian"; group = "everyday"; label = "Obsidian"; star = true; }
    { id = "libreoffice"; group = "everyday"; label = "LibreOffice"; }
    { id = "thunderbird"; group = "everyday"; label = "Thunderbird"; }
    { id = "calendar"; group = "everyday"; label = "GNOME Calendar (Google and Nextcloud sync)"; }
    { id = "bitwarden"; group = "everyday"; label = "Bitwarden"; }
    { id = "zathura"; group = "everyday"; label = "Zathura"; }
    { id = "localsend"; group = "everyday"; label = "LocalSend"; }

    { id = "spotify"; group = "media"; label = "Spotify"; star = true; }
    { id = "vlc"; group = "media"; label = "VLC"; star = true; }
    { id = "obs"; group = "media"; label = "OBS Studio"; }
    { id = "audacity"; group = "media"; label = "Audacity"; }

    { id = "gimp"; group = "creative"; label = "GIMP"; }
    { id = "krita"; group = "creative"; label = "Krita"; }
    { id = "inkscape"; group = "creative"; label = "Inkscape"; }
    { id = "kdenlive"; group = "creative"; label = "Kdenlive"; }
    { id = "blender"; group = "creative"; label = "Blender"; }

    { id = "photocraft"; group = "artcraft"; label = "PhotoCraft"; }
    { id = "vectorcraft"; group = "artcraft"; label = "VectorCraft"; }
    { id = "lightcraft"; group = "artcraft"; label = "LightCraft"; }
    { id = "pdfcraft"; group = "artcraft"; label = "PdfCraft"; }
    { id = "wordcraft"; group = "artcraft"; label = "WordCraft"; }
    { id = "soundcraft"; group = "artcraft"; label = "SoundCraft"; }
    { id = "deckcraft"; group = "artcraft"; label = "DeckCraft"; }
    { id = "cadcraft"; group = "artcraft"; label = "CADCraft"; }
    { id = "gridcraft"; group = "artcraft"; label = "GridCraft"; }

    { id = "steam"; group = "gaming"; label = "Steam"; }
    { id = "lutris"; group = "gaming"; label = "Lutris"; }
    { id = "heroic"; group = "gaming"; label = "Heroic Games Launcher"; }
    { id = "parsec"; group = "gaming"; label = "Parsec (client)"; }
    { id = "sunshine"; group = "gaming"; label = "Sunshine (stream this PC to Moonlight)"; }
    { id = "moonlight"; group = "gaming"; label = "Moonlight (play a Sunshine PC)"; }
    { id = "gamemode"; group = "gaming"; label = "GameMode"; }
    { id = "mangohud"; group = "gaming"; label = "MangoHud"; }
    { id = "protonup"; group = "gaming"; label = "ProtonUp-Qt"; }
    { id = "wine"; group = "gaming"; label = "Wine"; }
    { id = "osrs"; group = "gaming"; label = "Old School RuneScape (Bolt + RuneLite)"; }

    { id = "yazi"; group = "system"; label = "Yazi"; }
    { id = "snapper"; group = "system"; label = "Snapper"; btrfs = true; }
    { id = "remmina"; group = "system"; label = "Remmina (VNC and RDP viewer)"; }
    { id = "wayvnc"; group = "system"; label = "wayvnc (share this screen over VNC)"; }
    { id = "gparted"; group = "system"; label = "GParted"; }
    { id = "pokemon"; group = "system"; label = "Pokémon in fastfetch"; }
  ];

  langs = [
    { id = "python"; label = "Python"; }
    { id = "php"; label = "PHP"; }
    { id = "gdscript"; label = "GDScript (Godot)"; }
    { id = "js"; label = "JavaScript/TypeScript"; }
    { id = "rust"; label = "Rust"; }
    { id = "go"; label = "Go"; }
    { id = "cpp"; label = "C/C++"; }
    { id = "csharp"; label = "C#"; }
    { id = "java"; label = "Java"; }
    { id = "lua"; label = "Lua"; }
  ];
}
