# The optional app and language catalogue: pure data (no pkgs), read by the NixOS modules and
# by the installer (`nix eval --json .#lib.catalogue`). Labels match nusku-arch's
# packages/apps.list.
#   groups: { id; label; }
#   apps:   { id; group; label; star ? false (pre-selected); btrfs ? false (only on btrfs /); }
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

  # Sample entries; the full list lands with the apps module.
  apps = [
    { id = "firefox"; group = "everyday"; label = "Firefox"; star = true; }
    { id = "obsidian"; group = "everyday"; label = "Obsidian"; star = true; }
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
