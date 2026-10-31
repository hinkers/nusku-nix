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
