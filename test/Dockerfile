# Image for test/run-unit.sh (tag nusku-nix-test): bats, shellcheck and jq for the nusku-* scripts
# and the installer, python3 to byte-compile nusku-calendar-events, git for the exec-bit check and the
# installer's commits, neovim to run the Neovim Lua helpers under `nvim -l` (nvim-*.bats).
# The installer's menus are plain bash (no gum); lspci, nix and sudo are stubbed by the tests.
# A UTF-8 locale, as on a real terminal: the menus draw ★ ❯ ─ and read typed keys as characters.
FROM debian:trixie-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends bats shellcheck jq python3 git neovim ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=C.UTF-8
RUN useradd -m tester
USER tester
WORKDIR /nusku
