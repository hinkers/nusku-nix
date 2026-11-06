# shellcheck shell=bash
# Nusku - build and switch to a host, shared by install.sh and nusku-rebuild. Needs only bash and
# nixos-rebuild. Sourced, not executed.
#
#   nix_flakes_config            export NIX_CONFIG with flakes on (a fresh NixOS has them off);
#                                adds the setting once, keeping whatever NIX_CONFIG already had.
#   nusku_rebuild REPO HOST      nixos-rebuild switch --flake REPO#HOST, run as the user: the user
#                                evaluates and builds (own caches, nothing root-owned in the
#                                checkout); sudo only activates. Returns nixos-rebuild's status.
#                                NUSKU_FLAKE_ATTR, when set, is built instead of HOST: only the
#                                Hyper-V test VM sets it, to HOST-hyperv-test (test/hyperv).
#                                Any value not ending in -hyperv-test is refused (status 2).
#   nusku_sudo_upfront           ask for the sudo password now (unless sudo needs none), then keep
#                                it fresh in the background until the calling script exits, so the
#                                switch at the end of a long build doesn't stop to ask. Returns 1
#                                if sudo can't be had (wrong password, not in wheel).

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

nusku_sudo_upfront() {
    sudo -n true 2>/dev/null || sudo -v || return 1
    local script=$$
    (
        while kill -0 "$script" 2>/dev/null; do
            sudo -n true 2>/dev/null || true
            sleep 50
        done
    ) </dev/null >/dev/null 2>&1 &
}

nusku_rebuild() {
    nix_flakes_config
    local attr="${NUSKU_FLAKE_ATTR:-$2}"
    if [ -n "${NUSKU_FLAKE_ATTR:-}" ]; then
        case "$NUSKU_FLAKE_ATTR" in
            ?*-hyperv-test) ;;
            *)
                printf 'NUSKU_FLAKE_ATTR=%s refused: it is only for the Hyper-V test VM and must end in -hyperv-test (test/hyperv). Unset it to build %s.\n' "$NUSKU_FLAKE_ATTR" "$2" >&2
                return 2
                ;;
        esac
    fi
    [ "$attr" = "$2" ] || printf 'Building %s (NUSKU_FLAKE_ATTR) instead of %s\n' "$attr" "$2" >&2
    nixos-rebuild switch --flake "$1#$attr" "$(_rebuild_sudo_flag)"
}
