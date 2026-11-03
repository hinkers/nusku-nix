# nusku-nix

The Nusku desktop ([niri](https://github.com/YaLTeR/niri) in Catppuccin Mocha with your accent colour, from
[nusku-arch](https://github.com/hinkers/nusku-arch)) rebuilt on NixOS as a flake.

The installer asks its questions once and saves the answers for each machine in
`hosts/<name>/settings.json`, next to that machine's `hardware-configuration.nix`. Both are
committed, so any machine can be rebuilt the same way from the repo, and every rebuild can be
undone from the boot menu.

## Install

1. Install NixOS from the USB stick. In the graphical installer, pick **No desktop** on the
   Desktop page. Create your user there and connect to Wi-Fi if you need it.
2. Log in, then clone this repo and run the installer as your normal user (not root). If
   you're on Wi-Fi and it isn't connected, connect with `nmtui` first (the live USB's connection
   may not carry over to the installed system). A fresh NixOS has no git yet, so borrow it with
   `nix-shell`:

   ```sh
   nix-shell -p git --run 'git clone https://github.com/hinkers/nusku-nix.git'
   cd nusku-nix && ./install.sh
   ```

3. Answer the questions. They are one menu, like archinstall's: each setting shows its current
   value (the graphics, time zone and so on are detected for you). Use the arrow keys to move,
   Enter to change a setting, Esc to go back, and pick **Install** when it looks right.
4. Reboot when it asks, and log in.

The installer asks for your sudo password once, at the start (before the questions; the build
needs it to switch). It then writes `hosts/<name>/` (the host name you chose), commits it and
builds it. Push the commit (`git push`) so a reinstall can find it. Each run logs to
`~/.local/state/nusku/install-<time>.log`. `settings.json` also records the NixOS release you
installed (`stateVersion`); leave it as it is.

Before the build it checks your home for files where Nusku puts its own, such as an older
`~/.config/niri`, `~/.config/nvim` or `~/.zshrc` (from nusku-arch, or your own dotfiles). Home
Manager won't replace files it didn't make, so it lists them and offers to move them into
`~/nusku-backup-<time>/` (same layout) before building, or to stop. Nothing is deleted.

**From the first build on, the machine is built from this repo, not from
`/etc/nixos/configuration.nix`.** The installer carries over what that file needs for the machine
to boot: the boot and encryption settings the NixOS installer wrote there (GRUB's disk and
os-prober, GRUB's encrypted-disk support, the disk key file and every encrypted disk or swap
partition, and the EFI partition's mount point when it isn't `/boot`). It reads them from the
evaluated configuration and writes them to `hosts/<name>/installer.nix`, committed with the rest;
a plain unencrypted UEFI install has nothing to carry and gets no such file. Everything else in
`configuration.nix` is no longer used: users, Wi-Fi, packages and other settings come from
Nusku's modules. Your user's password is kept, and Wi-Fi networks you saved with NetworkManager
stay saved. If you added something else to `configuration.nix` that you want to keep, put it in
the repo before you run the installer.

## Reinstall a machine you already set up

Install NixOS as above, clone the repo (with the host committed and pushed), then:

```sh
./install.sh --host NAME
```

It asks nothing: it takes this machine's new `/etc/nixos/hardware-configuration.nix` (a
reinstall has new disk IDs) and the NixOS installer's boot and encryption settings
(`installer.nix`, as above) into `hosts/NAME`, commits them if they changed and builds. The user
named in `hosts/NAME/settings.json` must already exist on the new install. Running
`./install.sh` with no options on a machine whose host name already has a host does the same.

## Change your settings

```sh
./install.sh --apps          # tick or untick optional apps and languages, then rebuild
./install.sh --reconfigure   # open the whole settings menu again, then rebuild
```

Both start from the machine's saved answers, commit the change and rebuild. An app you untick is
removed by the rebuild.

**Accent colour:** pick another one with `./install.sh --reconfigure`, or change `"accent"` in
`hosts/NAME/settings.json` and run `nusku-rebuild`. Any of the 14 Catppuccin accents works:
rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire blue lavender.
Log out and back in after the rebuild to see the new colour everywhere. (nusku-arch's instant
`nusku-theme` is gone: the colours are part of the build.)

**Any other app:** add its nixpkgs name to `"packages"` in `hosts/NAME/settings.json` and run
`nusku-rebuild`. Find the name with `nix search nixpkgs NAME` (or search.nixos.org); names with
a dot work too:

```json
"packages": ["htop", "kdePackages.kate"]
```

A name that isn't in nixpkgs stops the rebuild and says which one. The installer never asks
about these and keeps them when you change your settings. To offer an app on every machine (in
the installer's list), add it to `lib/catalogue.nix` and `modules/nixos/apps.nix` instead.

The wallpaper picker (Super + Alt + W) is instant and isn't part of the build; your choice is kept.

## The desktop

niri lays windows out in columns on an endless strip that scrolls sideways, with workspaces
stacked above and below; Super + O shows them all. The keybinds (`config/niri/binds-nusku.kdl`):

- Super + Return terminal, Super + Space app launcher, Super + E files, Super + B browser
- Super + H J K L or the arrows: move between windows; add Shift to move the window
- Super + U / D: the workspace above / below (Shift moves the window there); Super + 1…0 a
  numbered workspace
- Super + Q close, Super + F maximize (full width), Super + M maximize to the edges, Super +
  Shift + F fullscreen, Super + T float, Super + Shift + T column as tabs,
  Super + P cycle the column width, Super + Ctrl + arrows resize
- Super + N quick settings, Super + V clipboard, Super + W wallpaper, Super + Escape power
  menu, Super + Alt + L lock
- Super + / searches every bind (and runs the one you pick); Super + Shift + / is niri's list

The bar, the quick settings panel and the notifications are Nusku's own shell, built with
[Quickshell](https://quickshell.org) (`config/quickshell/nusku`, in your accent colour):

- The bar: workspaces, the window title, the clock (click for the calendar), the tray, the
  battery and one pill for network, Bluetooth and notifications.
- The pill (or Super + N) opens quick settings: Wi-Fi and Bluetooth (› picks a network or a
  device), Do Not Disturb, night light, airplane mode, keep awake, mute, screenshot, power,
  brightness and volume, power profiles, what's playing, and the notifications. Right-click
  the pill's network or Bluetooth icon for its picker, the bell for Do Not Disturb.
- New notifications pop up in the top right corner; critical ones stay until you close them.

It runs as the `nusku-shell` user service (`systemctl --user restart nusku-shell` if it ever
needs a kick). Scripts can drive it, e.g. `qs -c nusku ipc call panel toggle`.

niri's own default binds, with Nusku's apps and menus added, are in
`config/niri/binds-niri.kdl`. To use them instead, change `include "binds-nusku.kdl"` to
`include "binds-niri.kdl"` in `config/niri/config.kdl` and run `nusku-rebuild`.

The lock screen is hyprlock (it locks after 10 minutes idle, and the screens turn off a minute
later); screenshots are niri's own (Print, then Enter to save the region: they go to the
clipboard and `~/Pictures/Screenshots`).

## Everyday commands

```sh
nusku-rebuild   # apply your edits: build this machine from your checkout and switch to it
nusku-update    # update everything: git pull, newer packages (flake.lock), rebuild
```

**nusku-rebuild** builds `hosts/<this machine's host name>` from your checkout and switches to it.
Use it after you edit anything in the checkout (a host's `settings.json`, a file in `config/`,
a module). The build only sees files git knows about, so `git add` a new file first.

**nusku-update**, in your checkout:

1. stops at once if you have uncommitted changes (commit or stash them first),
2. runs `git pull --ff-only` and stops if that can't fast-forward (for example when this machine
   and the remote both have new commits), without changing anything,
3. runs `nix flake update` (newer nixpkgs, Home Manager and catppuccin/nix in `flake.lock`),
4. rebuilds and switches, like `nusku-rebuild`,
5. asks whether to commit `flake.lock`, and commits only that file if you say yes. Push it so
   your other machines get the same versions.

If the build fails, `flake.lock` stays updated but not committed. Go back to the old versions
with `git checkout flake.lock` in the checkout.

Both commands find your checkout through `~/.config/nusku/repo`, which the installer writes (it
holds the checkout's path and isn't part of the repo). If you move the checkout, run
`./install.sh --host NAME` from its new place, or set `NUSKU_REPO` to it (that wins over the
file).

**Neovim's plugins update separately.** LazyVim and the other Neovim plugins are pinned by
`config/nvim/lazy-lock.json`, but nvim-treesitter with its parsers and blink.cmp (with its
compiled fuzzy matcher, which it would otherwise download from GitHub) come from nixpkgs, so they
move with `flake.lock`. When you bump one, bump the other: after `nix flake update`, regenerate
`lazy-lock.json` with every language enabled (Mason, nvim-treesitter and blink.cmp stay out of
it) and check
that Neovim still starts cleanly. Neovim follows a new `lazy-lock.json` by itself: the first time
it starts (with a window) after a rebuild that changed the pins, it replaces its own copy
(`~/.local/share/nvim/lazy-lock.json`) and restores the plugins to them. If that fails (offline),
it says so and tries again each time it starts. A rebuild that leaves `lazy-lock.json` alone
keeps your copy, so a `:Lazy update` sticks until the next new pins.

## Going back: the boot menu

Every rebuild is a new entry ("generation") in the boot menu. If a rebuild leaves the machine
broken, reboot and pick the entry before it. That goes back to the old system; it doesn't
change your files or the repo. Fix the problem in the checkout and run `nusku-rebuild` again.

## Your own files

Nusku creates these once and never overwrites them:

- `~/.config/nusku/local.kdl` — your niri settings (monitors, input, extra binds). It is
  included last, so it wins; a key you bind there replaces Nusku's bind for that key.
- `~/.config/nusku/local.zsh` — your zsh additions, sourced at the end of `~/.zshrc`.

Built-in 1920×1200 and 1920×1080 laptop screens start at 1.25× scale; an `output` block in
`local.kdl` overrides that. niri's config is [KDL](https://yalter.github.io/niri/Configuration:-Introduction.html),
and niri reloads it as soon as you save. For example:

```kdl
output "DP-1" { mode "2560x1440@144"; scale 1; position x=0 y=0; }
input { keyboard { xkb { layout "us,de"; options "grp:alt_shift_toggle"; } } }
binds {
    Mod+Shift+D hotkey-overlay-title="Discord" { spawn "discord"; }
}
```

Binds with a `hotkey-overlay-title` show in niri's keybind list (Super + Shift + /).

Most of the other configs Nusku sets up in your home folder (niri, the shell, kitty and so on)
are links into the build, so they are read-only: change them in the checkout's `config/` and
run `nusku-rebuild`.

## Apps

The optional apps and languages are the same groups as nusku-arch's, with the ★ apps picked on
a fresh install. Pick at least one web browser. Links and Super + B open the first picked
browser in the list's order (Firefox, Chromium, Brave, LibreWolf), unless you chose another
default yourself. Notes on some of the apps:

### Browsers and Obsidian

These get Catppuccin (Mocha) when they are picked:

- **Firefox**: Home Manager manages one profile, `default`, in `~/.config/mozilla/firefox`. The
  theme is a Firefox Color setting in your accent. Firefox Color itself is a fixed copy from the
  Nix store, installed by policy, so no network is needed. An existing `~/.mozilla/firefox` is
  not touched; if you have one, Firefox may keep starting from it, unthemed. If you already have a
  `~/.config/mozilla/firefox/profiles.ini` that Home Manager didn't make, the installer offers to
  move it aside (see Install). `nusku-rebuild` doesn't check first: there, Home Manager won't
  replace it, so your desktop configs aren't updated and the rebuild reports an error: move it
  away (for example `mv ~/.config/mozilla/firefox ~/firefox-old`) and run `nusku-rebuild`
  again.
- **Chromium** and **Brave**: catppuccin's Mocha theme extension, which the browser downloads
  from the Chrome Web Store (there is no accent choice). This is the one accepted exception to
  "nothing installed outside Nix". You may have to confirm it once.
- **LibreWolf**: left as it is.
- **Obsidian**: every vault Obsidian knows gets the Catppuccin theme (Mocha in dark mode) in
  `.obsidian/themes/Catppuccin`, refreshed on each rebuild and at each login, so a new vault is
  themed by the next login. Catppuccin is switched on once per vault (where no other theme was
  chosen); anything you pick later in Obsidian, including Default, sticks. It uses Catppuccin's
  own accent; change it with Obsidian's Style Settings plugin.

### Neovim and languages

Each picked language installs its runtime and package manager (Python + uv, Node, Go, ...).
With Neovim picked, it also gets the language servers, formatters and linters that its LazyVim
extra uses, from nixpkgs (`lib/langs.nix`); without Neovim it gets none. Mason is off, so an extra
you turn on later with `:LazyExtras` gets **no tools**: add them to the language in
`lib/langs.nix` and rebuild. Treesitter parsers come from Nix as well, so `:TSInstall` and
`:TSUpdate` can't install anything.

Rust: rustup gets a stable toolchain with rust-analyzer and rustfmt from the `nusku-rustup`
background service after you log in. It needs the network once and retries every minute until
it works (`systemctl --user status nusku-rustup`).

### Docker

Picking Docker adds you to the `docker` group, which is root-equivalent: anyone in it can take
over the machine. Log out and back in to use `docker` without sudo. Compose is the plugin,
`docker compose`; there is no separate `docker-compose` command.

### Sunshine, Moonlight and wayvnc

- **Sunshine** streams this PC to Moonlight on another device. It starts at login. Open
  https://localhost:47990 on this PC to create its login, then pick this PC in Moonlight and type
  the PIN it shows into that page. Only the streaming ports are opened; the settings page stays
  reachable from this PC only.
- The build may print warnings about obsolete Avahi options when Sunshine is picked. They come
  from nixpkgs' own Sunshine module and are harmless.
- **wayvnc** shares this screen. It starts at login and listens on port 5900, which is opened in
  the firewall. Connect with a VNC viewer (Remmina, TigerVNC) to `this-pc:5900` and log in with
  this PC's user name and password. The connection is always encrypted; the viewer may ask you
  to accept the PC's certificate the first time. Viewers that only know plain VNC passwords
  can't connect. `systemctl --user status wayvnc` shows whether it's running.

### Old School RuneScape

The app is **Bolt Launcher**. Log in with your Jagex account there, then pick RuneLite (or the
official client) and Play; Bolt downloads and updates the client itself.

### Snapper

Snapper takes timed snapshots of `/home`, and only when `/home` is its own btrfs partition. The
installer offers it only then. The whole system is already covered by the boot menu's
generations.

## Differences from nusku-arch

The desktop looks and works the same. What changed:

- **Answers live in the repo**, in `hosts/<name>/settings.json`, instead of
  `~/.config/nusku/answers`. A reinstall is `./install.sh --host NAME`; there is no
  `--answers FILE`.
- **Updating and rolling back:** `nusku-update` updates the pinned packages and rebuilds;
  `nusku-rebuild` applies your edits; any rebuild can be undone from the boot menu.
- **The accent is part of the build:** change it and rebuild (no instant `nusku-theme`).
- **Unticking an app removes it** on the rebuild.
- **Nothing is installed outside Nix:** no AUR (and no AUR helper question), no Flatpak, no
  ArtCraft Launcher, and Mason is off in Neovim (the language tools come from nixpkgs). The only
  exception is the Chromium/Brave theme from the Chrome Web Store.
- **Dropped apps:** Zen Browser (not in nixpkgs), Flatpak, and the UFW firewall (NixOS's own
  firewall is on instead, with the ports LocalSend and Sunshine need). No multilib question:
  Steam turns on 32-bit support itself.
- **ArtCraft:** the 9 apps nixpkgs has (PhotoCraft, VectorCraft, LightCraft, PdfCraft,
  WordCraft, SoundCraft, DeckCraft, CADCraft, GridCraft), updated when nixpkgs updates them.
  FilmCraft, EffectCraft, DesignCraft and FigCraft aren't available.
- **Bitwarden and LibreWolf** come from nixpkgs instead of Flatpak.
- **Also themed:** Firefox, Chromium, Brave and Obsidian (see above), bat, fzf and eza, lazygit,
  Zathura, MangoHud and OBS when picked, and the GRUB boot menu (on machines that boot with
  GRUB) and the text console. lazygit, Zathura and MangoHud keep their config files yours:
  Nusku writes `~/.config/lazygit/config.yml`, `zathura/zathurarc` and `MangoHud/MangoHud.conf`
  only when they don't exist yet, so an existing one stays as it is (unthemed). OBS gets the
  Catppuccin themes, but you pick **Catppuccin Mocha** once in Settings → Appearance.
- **No backups folder:** Nusku doesn't copy your files aside. Home Manager refuses to replace a
  file it didn't make (the rebuild reports it), so nothing is lost.
- **Snapper** covers only `/home`; the system rolls back through the boot menu.

## Layout

- `install.sh`, `lib/sh/` — the installer and the shell code that `nusku-rebuild` and
  `nusku-update` share with it.
- `hosts/<name>/` — each machine's `settings.json` and `hardware-configuration.nix`, and its
  `installer.nix` when the NixOS installer set up encryption or GRUB (`lib/installer-config.nix`).
- `flake.nix` — `nixosConfigurations.<name>` for every `hosts/<name>/`.
- `lib/hosts.nix` — builds a host from its `settings.json`.
- `lib/catalogue.nix` — the optional apps and languages (see them as JSON with
  `nix eval --json .#lib.catalogue`).
- `modules/nixos/` — the system; `modules/nixos/options.nix` holds the `nusku.*` options the
  settings fill in.
- `modules/home/` — your user's side (Home Manager): dotfiles, theme, apps.
- `config/` — the dotfiles, from nusku-arch. `scripts/` — the `nusku-*` commands.

## Tests

Both need Docker (Docker Desktop on Windows) running.

```sh
bash test/run-unit.sh            # shellcheck + the bats tests for the installer and scripts
bash test/run-unit.sh everyday   # only test/unit/everyday.bats
bash test/run-eval.sh            # evaluate every test host and check (nothing is built)
bash test/run-eval.sh vm-min     # one check
```

The flake only sees files git knows about: `git add` new files before running the eval tests.

End to end, on Windows with Hyper-V: a NixOS VM that installs your working tree, reboots into
the desktop, checks it and takes screenshots. See [test/hyperv/README.md](test/hyperv/README.md).
