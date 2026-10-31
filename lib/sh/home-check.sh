# shellcheck shell=bash
# Nusku - files in the home that Home Manager would have to replace. Home Manager never replaces a
# file it didn't make, so a leftover (nusku-arch's ~/.config/hypr, kitty, nvim, ~/.zshrc, ...)
# stops the switch. Before the build, install.sh lists them and offers to move them aside to a
# timestamped folder, or to stop. Nothing is ever deleted.
#
# What to look at is lib/home-paths.txt (test/eval/home-paths.nix keeps it matched to the Home
# Manager config):
#   name     in the way when it exists and isn't a link into the Nix store
#   name/    a directory: in the way when it has files but no link into the Nix store anywhere
#            inside (a directory Home Manager already fills has its links in it)
#   name*    each existing path starting with name, checked like `name`
#
#   home_in_the_way          the paths in the way, relative to $HOME, one per line
#   home_move_aside PATH...  move them into ~/nusku-backup-<time>/ (same layout); prints that folder
#   home_check               the whole step: list, explain, ask (Move or Stop)
#
# Sourced, not executed. Needs lib/sh/log.sh, and for home_check lib/sh/tui.sh and tui_usable
# (install.sh). home_check sets HOME_BACKUP to the folder it moved things to.

# shellcheck disable=SC2034 # read by install.sh
HOME_BACKUP=""

_home_store_link() {
    [ -L "$1" ] && case "$(readlink "$1")" in /nix/store/*) true ;; *) false ;; esac
}

# _home_blocks PATH: status 0 when PATH (absolute) would stop Home Manager. DIR is 1 for a
# directory entry.
_home_blocks() {
    local path="$1" dir="$2"
    [ -e "$path" ] || [ -L "$path" ] || return 1
    ! _home_store_link "$path" || return 1
    if [ "$dir" = 1 ] && [ -d "$path" ] && [ ! -L "$path" ]; then
        # Home Manager's already: some link inside points into the store.
        [ -z "$(find "$path" -lname '/nix/store/*' -print -quit 2>/dev/null)" ] || return 1
        # Empty: nothing to collide with.
        [ -n "$(find "$path" -mindepth 1 \( -type f -o -type l \) -print -quit 2>/dev/null)" ] || return 1
    fi
    return 0
}

home_in_the_way() {
    local list="$NUSKU_ROOT/lib/home-paths.txt" entry path
    [ -r "$list" ] || return 0
    while IFS= read -r entry; do
        case "$entry" in "" | "#"*) continue ;; esac
        case "$entry" in
            */) _home_blocks "$HOME/${entry%/}" 1 && printf '%s\n' "${entry%/}" ;;
            *"*")
                for path in "$HOME/${entry%\*}"*; do
                    _home_blocks "$path" 0 && printf '%s\n' "${path#"$HOME"/}"
                done
                ;;
            *) _home_blocks "$HOME/$entry" 0 && printf '%s\n' "$entry" ;;
        esac
    done <"$list"
    return 0
}

home_move_aside() {
    local backup p
    backup="$HOME/nusku-backup-$(date +%Y%m%d-%H%M%S)"
    for p in "$@"; do
        mkdir -p "$backup/$(dirname "$p")"
        mv -- "$HOME/$p" "$backup/$p"
    done
    printf '%s\n' "$backup"
}

home_check() {
    local -a paths=()
    local p backup shown=""
    mapfile -t paths < <(home_in_the_way)
    [ "${#paths[@]}" -gt 0 ] || return 0
    log_warn "These are in your home already and weren't made by Home Manager. It won't replace them, so the build would stop:"
    for p in "${paths[@]}"; do
        log_warn "  ~/$p"
    done
    log_warn "They are probably left over from an earlier setup (nusku-arch, or your own dotfiles). Moving them aside keeps them: nothing is deleted."
    if ! tui_usable; then
        die "Move them out of the way (for example into ~/nusku-backup), then run this again."
    fi
    for p in "${paths[@]:0:3}"; do
        shown="${shown:+$shown, }~/$p"
    done
    [ "${#paths[@]}" -le 3 ] || shown="$shown and $((${#paths[@]} - 3)) more"
    tui_open "${NUSKU_ANSWERS[ACCENT]:-blue}"
    if tui_choose "Files in the way" "Home Manager won't replace $shown." 0 \
        "Move them to ~/nusku-backup-<time> and build" "Stop (nothing is changed)" && [ "$TUI_CHOICE" -eq 0 ]; then
        tui_close
        backup="$(home_move_aside "${paths[@]}")"
        log_info "Moved ${#paths[@]} to $backup (copy back what you need from there)"
        HOME_BACKUP="$backup"
        return 0
    fi
    tui_close
    die "Stopped before the build; nothing was moved. Move those files aside yourself, then run this again."
}
