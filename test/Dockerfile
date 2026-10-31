# Image for test/run-unit.sh (tag nusku-nix-test): bats, shellcheck and jq for the nusku-* scripts,
# python3 to byte-compile nusku-calendar, git for the exec-bit check, neovim to run the Hyprland Lua
# config under `nvim -l` (keybinds.bats). The installer's tests (Task 10) add gum etc. here.
FROM debian:trixie-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends bats shellcheck jq python3 git neovim ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m tester
USER tester
WORKDIR /nusku
