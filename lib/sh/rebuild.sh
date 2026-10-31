# shellcheck shell=bash
# Nusku - build and switch to a host, shared by install.sh and nusku-rebuild. Needs only bash and
# nixos-rebuild. Sourced, not executed.
#
#   nix_flakes_config            export NIX_CONFIG with flakes on (a fresh NixOS has them off);
#                                adds the setting once, keeping whatever NIX_CONFIG already had.
#   nusku_rebuild REPO HOST      nixos-rebuild switch --flake REPO#HOST, run as the user: the user
#                                evaluates and builds (own caches, nothing root-owned in the
#                                checkout); sudo only activates. Returns nixos-rebuild's status.

nix_flakes_config() {
    case "${NIX_CONFIG:-}" in
        *"extra-experimental-features = nix-command flakes"*) ;;
        *) NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG$'\n'}extra-experimental-features = nix-command flakes"$'\n'"warn-dirty = false" ;;
    esac
    export NIX_CONFIG
}

# _rebuild_sudo_flag: --sudo (nixos-rebuild-ng), or --use-remote-sudo for the older nixos-rebuild
# a fresh install may still run on its first build.
_rebuild_sudo_flag() {
    local help
    help="$(nixos-rebuild --help 2>&1 || true)"
    case "$help" in
        *--sudo*) echo --sudo ;;
        *) echo --use-remote-sudo ;;
    esac
}

nusku_rebuild() {
    nix_flakes_config
    nixos-rebuild switch --flake "$1#$2" "$(_rebuild_sudo_flag)"
}
