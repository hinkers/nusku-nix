# nusku-nix — design

Date: 2026-10-31. A NixOS rebuild of Nusku. The Arch version (`C:\Users\hinke\Repos\Nusku`,
GitHub `hinkers/Nusku`, being renamed to `nusku-arch`) is the **behaviour reference**: when this
document says "as in nusku-arch", read that repo (its README, `docs/superpowers/specs/`,
`config/`, `scripts/`, `lib/`, `packages/apps.list`) for the exact look and behaviour.

## 1. Intent

The owner has a finished, hardware-tested Arch + Hyprland bootstrap (nusku-arch). They want the
same desktop on NixOS because:

- **Reproducibility** (the main reason): a machine's whole setup lives in the repo; a wiped or new
  machine comes back identical.
- **Rollback**: every rebuild is a boot-menu generation.
- **More theming**: Firefox, Chromium and Obsidian themed too (they aren't in nusku-arch).

nusku-arch stays as it is in its own repo; nusku-nix is a new repo (`nusku-nix`).

## 2. Goals, non-goals, anti-goals

**Goals**
- Same install feel as nusku-arch: minimal NixOS install from the USB, clone the repo, run one
  script, answer the questions once, get the full desktop.
- The answers become committed config per machine; reinstalling a known machine asks nothing.
- Same look and behaviour as nusku-arch (§6), plus Firefox, Chromium and Obsidian themed.
- Everything declarative: no tool installs software outside Nix.

**Non-goals**
- Porting nusku-arch's Bash installer machinery (backups, pacman/AUR handling, multilib, Flatpak).
- Disk partitioning, encryption, user creation: the NixOS installer does those.
- Supporting Google Chrome theming (Chromium replaces Chrome).
- Secrets management.

**Anti-goals** (failure even if it technically works)
- Anything installed behind Nix's back (Mason downloads, the ArtCraft Launcher, Flatpak apps).
- A machine that can't be rebuilt identically from the repo plus its committed host files.
- Losing nusku-arch behaviour the owner added during hardware testing (§6).

## 3. Decided (with the owner)

- **New repo** `nusku-nix`; nusku-arch is kept separately.
- **Flow:** minimal NixOS install → `git clone` → run the script → it asks the questions in the
  same archinstall-style settings menu as nusku-arch (`lib/tui.sh`, `lib/questions.sh`) → writes
  `hosts/<name>/` → builds. Each machine's choices are committed to the repo; a reinstall is
  clone + pick the host + build, no questions. Re-running with `--apps` changes picks (as in
  nusku-arch).
- **Channel:** nixos-unstable (Hyprland 0.57 today, so the Lua config carries over; stable 26.05
  has 0.55). Rollback is the safety net.
- **Theming tool:** catppuccin/nix (official Catppuccin modules) wherever it covers an app,
  including Firefox (per profile), Chromium (extension) and Obsidian. Own templates fill gaps.
- **Browsers:** Chromium instead of Chrome; Chromium gets the Catppuccin theme.
- **ArtCraft:** use nixpkgs only. The group has the 9 apps nixpkgs packages (PhotoCraft,
  VectorCraft, LightCraft, PdfCraft, WordCraft, SoundCraft, DeckCraft, CADCraft, GridCraft),
  updated when nixpkgs updates them. No launcher, no FilmCraft/EffectCraft/DesignCraft/FigCraft.
- **Neovim:** LazyVim kept, Mason turned off; each picked language also installs its LSP,
  formatter and linter from nixpkgs (the tools the matching LazyVim extra expects, e.g. Python →
  basedpyright + ruff). Treesitter parsers from Nix too (not compiled at runtime).
- **Pokémon fastfetch option** kept (nixpkgs `krabby`, random Gen 1–3, default shiny rate).

## 4. Builder's calls (made by Claude during design, open to change)

- **Repo shape:** a flake (pinned `flake.lock`), NixOS modules for the system, Home Manager for
  the user's dotfiles and per-user app config. Inputs: nixpkgs (unstable), home-manager,
  catppuccin/nix.
- **Host files:** `hosts/<name>/default.nix` (the answers as Nix options: GPU, NVIDIA driver,
  accent, apps, languages, …) + `hosts/<name>/hardware-configuration.nix` (copied from
  `/etc/nixos`). The flake lists every host under `nixosConfigurations.<name>`.
- **Options module:** a `nusku.*` option set (e.g. `nusku.gpu`, `nusku.nvidia`, `nusku.accent`,
  `nusku.apps = [ "firefox" "obsidian" … ]`, `nusku.langs = [ … ]`) that the rest of the config
  reads. The catalogue (groups, labels, ★ defaults, what each app turns on) is one Nix data file
  the script also reads (via `nix eval --json`), replacing `packages/apps.list`.
- **Everyday commands:** `nusku-update` = `nix flake update` + rebuild; a rebuild command for
  "apply my edits". Accent change = re-pick (or edit the host file) + rebuild; no instant
  `nusku-theme` re-render. The wallpaper picker stays instant (it's runtime state, like now).
- **Mutable bits:** wallpaper choice and `local.lua` / `local.zsh` overrides stay as user files
  outside the repo, as in nusku-arch.
- **Firewall:** NixOS's built-in firewall replaces UFW (on by default; LocalSend, Sunshine and SSH
  ports opened by the apps that need them).
- **Snapper:** optional, `/home` snapshots on btrfs only (system rollback is generations).
- **Dropped:** AUR helper question, multilib, Flatpak, UFW, ArtCraft Launcher, Zen Browser
  (owner's decision; not in nixpkgs).
- **Testing:** the Hyper-V loop as in nusku-arch (`test/hyperv/`), with a NixOS VM: install
  minimal NixOS, checkpoint, clone, run the script with an answers/host file, build, boot, run
  the same kinds of checks and screenshots. Plus `nix flake check` and evaluation tests per host
  in CI-able form.

## 5. App catalogue

Same groups, apps, ★ defaults and languages as nusku-arch's `packages/apps.list`, with these
changes (checked against nixpkgs unstable 2026-10-31; everything else is in nixpkgs):

- **System-level apps become NixOS options:** Docker (`virtualisation.docker`), Steam
  (`programs.steam`), GameMode, Sunshine (service + Avahi + firewall ports), Moonlight, wayvnc.
- **libreoffice-fresh** → `libreoffice` (renamed upstream). **Kdenlive** → `kdePackages.kdenlive`.
  **Godot** → `godot_4`. **Bitwarden**, **LibreWolf**: nixpkgs instead of Flatpak.
- **Docker group membership**, **GameMode group**, **zathura as PDF default**, **rustup default**
  and other nusku-arch app hooks become declarative settings.
- **ArtCraft:** 9 apps (§3). **Zen Browser, UFW, Flatpak:** removed.
- **Unfree** packages (Discord, Obsidian, Spotify, Steam, VS Code, Claude Code, Parsec, NVIDIA)
  need `allowUnfree` (or a per-package allow list).

## 6. Behaviour carried over from nusku-arch (must match)

Read nusku-arch for exact behaviour of each:

- **Installer UX:** the archinstall-style settings menu with the folding app list.
- **Bar and panels:** one quick-settings Waybar pill (no volume module); the swaync quick-settings
  panel with Wi-Fi and Bluetooth split buttons (Rofi pickers), sound mute and mic mute tiles,
  per-app volume and a night-light toggle (hyprsunset); matching pop-up notifications; the clock
  click-drop-down month calendar with event dots synced via GNOME Calendar + Online Accounts
  (`scripts/nusku-calendar`, python-gobject, gtk4-layer-shell); network right-click opens the
  connection editor.
- **Desktop:** the Hyprland Lua config, keybinds, the searchable keybind menu (SUPER + /), Super+B
  default browser (warn when none), 1.25x scale on 1920×1200/1920×1080 laptop panels, swaync
  started through systemd, Kitty not remembering window size, Hyprlock, hypridle, clipboard
  history, screenshots, the power/clipboard/wallpaper menus.
- **Look:** Catppuccin Mocha + accent across GTK, Qt/Kvantum, cursors, SDDM, Hyprlock, Rofi,
  Waybar, Kitty, btop, Starship, Yazi, Neovim, fastfetch; Papirus folders in the accent colour;
  launcher icon clean-up; wallpapers (4×3 thumbnail picker, choice persists).
- **Hardware:** GPU choice incl. hybrid laptops and the NVIDIA driver choice (open vs legacy
  proprietary), `sof-firmware` for Intel laptop audio.
- **Shell:** zsh + Starship, fastfetch greeting + optional Pokémon.

## 7. Left to the builder

- Module layout, the exact catalogue format, how the script writes host files (generate Nix
  text vs a JSON file the flake imports — JSON is easier for the script to edit and still
  committed).
- How LazyVim gets plugins without runtime downloads breaking reproducibility (lazy.nvim with a
  committed lockfile is acceptable — it's pinned like nusku-arch — or Nix-provided plugins).
- Hyprland module vs plain package; how the Lua config files are linked (Home Manager
  `xdg.configFile`); how accent templating maps onto Nix (string interpolation of the palette).
- How nusku-arch's tests translate (bats for the script, Nix eval checks for modules).
