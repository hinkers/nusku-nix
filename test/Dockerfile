# Image for test/run-unit.sh (tag nusku-nix-test): bats, shellcheck and jq for the nusku-* scripts,
# python3 to byte-compile nusku-calendar. The installer's tests (Task 10) add gum, git etc. here.
FROM debian:trixie-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends bats shellcheck jq python3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m tester
USER tester
WORKDIR /nusku
