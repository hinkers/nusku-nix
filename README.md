# nusku-nix

The Nusku desktop (Catppuccin Mocha + Hyprland, from
[nusku-arch](https://github.com/hinkers/nusku-arch)) rebuilt on NixOS as a flake. Each machine's
installer answers live in `hosts/<name>/settings.json` next to its
`hardware-configuration.nix`, so any machine rebuilds identically and rolls back from the boot
menu.

Work in progress: the installer and the desktop modules are still being built.

## Layout

- `flake.nix` — `nixosConfigurations.<name>` for every `hosts/<name>/`.
- `lib/hosts.nix` — builds a host from its `settings.json`.
- `lib/catalogue.nix` — optional apps and languages (`nix eval --json .#lib.catalogue`).
- `modules/nixos/options.nix` — the `nusku.*` options the settings fill in.

## Tests

Docker Desktop must be running; nothing is built, only evaluated.

```sh
bash test/run-eval.sh          # every check + the bad-settings fixtures
bash test/run-eval.sh vm-min   # one check
```

Flakes only see files git tracks: `git add` new files first.

## Browser and Obsidian theming

These get Catppuccin from catppuccin/nix when they are picked (Mocha; the host's accent
where it offers one):

- **Firefox** — Home Manager manages one profile, `default`, in `~/.config/mozilla/firefox`
  (and its `profiles.ini`). The theme is a Firefox Color setting in the host's accent; Firefox
  Color itself is a pinned copy in the Nix store, installed by policy, so no network is needed.
  An existing `~/.mozilla/firefox` is not touched; if it exists, Firefox may keep starting
  from it, unthemed.
- **Chromium** and **Brave** — catppuccin's Mocha theme extension, which the browser fetches
  from the Chrome Web Store (no accent choice there). This is the one accepted exception to
  "nothing installed outside Nix". You may have to confirm it once.
- **LibreWolf** — left default.
- **Obsidian** — every vault Obsidian knows (its own vault list) gets the Catppuccin theme
  (Mocha in dark mode) in `.obsidian/themes/Catppuccin`, refreshed on each rebuild and at each
  login, so a new vault is themed by the next login. Catppuccin is switched on once per vault
  (where no other theme was chosen); any later choice in Obsidian, including Default, sticks.

## Neovim and languages

Each picked language installs its runtime and package manager (Python + uv, Node, Go, ...)
system-wide. With Neovim picked it also gets the language servers, formatters and linters its
LazyVim extras use, from nixpkgs (`lib/langs.nix`); without Neovim it gets none. Mason is off,
so an extra you turn on later with `:LazyExtras` gets **no tools**: add them to the host (or to
the language in `lib/langs.nix`) and rebuild. Treesitter parsers come from Nix; `:TSInstall` and
`:TSUpdate` can't install anything.

Rust: `rustup` gets a stable default toolchain with rust-analyzer and rustfmt from the
`nusku-rustup` user service after login (it needs the network once and retries every minute
until it succeeds; `systemctl --user status nusku-rustup`).

## Updating

- **nvim-treesitter moves with `flake.lock`** (nixpkgs' copy and its grammars), while LazyVim
  and the other Neovim plugins are pinned by `config/nvim/lazy-lock.json`. Bump them together:
  after `nix flake update`, regenerate `lazy-lock.json` with every language enabled (Mason and
  nvim-treesitter stay out of it) and check Neovim still starts cleanly.
- Neovim follows a new `lazy-lock.json` by itself: on the first start after the rebuild it
  replaces its own copy (`~/.local/share/nvim/lazy-lock.json`) and restores the plugins to the
  new pins. `:Lazy update` between rebuilds only changes that copy until the next new pins.
