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
