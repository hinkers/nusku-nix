#!/usr/bin/env bash
# Nusku installer: turns a fresh minimal NixOS install into the Nusku Hyprland desktop.
# It writes this machine's answers to hosts/<name>/ (committed), then builds that host.
# Run as your normal user (not root). See usage() or ./install.sh --help.
set -Eeuo pipefail

NUSKU_ROOT="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export NUSKU_ROOT

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Turns a fresh minimal NixOS install into the Nusku Hyprland desktop. Run it as your normal
user; it asks for sudo for the build. Safe to re-run.

  (no options)     First run: asks the questions, writes hosts/<name>/, commits and builds it.
                   On a machine that already has its host (hosts/<hostname>), rebuilds it.
  --host NAME      Reinstall a known machine: no questions. Takes this machine's
                   /etc/nixos/hardware-configuration.nix (its disk IDs) and the NixOS
                   installer's boot and encryption settings into hosts/NAME, builds.
  --apps           Change this machine's optional apps and languages, then rebuild.
  --reconfigure    Open the settings menu again on this machine's settings, then rebuild.
  --no-reboot      Do not offer to reboot at the end.
  -h, --help       Show this help.
EOF
}

args=("$@")
opt_host=""
opt_apps=0
opt_reconfigure=0
opt_no_reboot=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --host)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                printf 'install.sh: --host needs a name\n' >&2
                exit 2
            fi
            opt_host="$2"
            shift 2
            ;;
        --host=*)
            opt_host="${1#--host=}"
            shift
            ;;
        --apps) opt_apps=1 && shift ;;
        --reconfigure) opt_reconfigure=1 && shift ;;
        --no-reboot) opt_no_reboot=1 && shift ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'install.sh: unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done
modes=$((opt_apps + opt_reconfigure))
[ -z "$opt_host" ] || modes=$((modes + 1))
if [ "$modes" -gt 1 ]; then
    printf 'install.sh: use only one of --host, --apps and --reconfigure\n' >&2
    exit 2
fi

# shellcheck source=lib/sh/log.sh
source "$NUSKU_ROOT/lib/sh/log.sh"
# shellcheck source=lib/sh/host.sh
source "$NUSKU_ROOT/lib/sh/host.sh"
# shellcheck source=lib/sh/detect.sh
source "$NUSKU_ROOT/lib/sh/detect.sh"
# shellcheck source=lib/sh/tui.sh
source "$NUSKU_ROOT/lib/sh/tui.sh"
# shellcheck source=lib/sh/questions.sh
source "$NUSKU_ROOT/lib/sh/questions.sh"
# shellcheck source=lib/sh/rebuild.sh
source "$NUSKU_ROOT/lib/sh/rebuild.sh"
# shellcheck source=lib/sh/installer-config.sh
source "$NUSKU_ROOT/lib/sh/installer-config.sh"
# shellcheck source=lib/sh/home-check.sh
source "$NUSKU_ROOT/lib/sh/home-check.sh"

# A fresh NixOS has flakes switched off: every nix and nixos-rebuild call here gets them (once:
# the re-run inside `nix shell` below inherits them).
nix_flakes_config

[ -e "${NUSKU_NIXOS_MARKER:-/etc/NIXOS}" ] ||
    die "nusku-nix only installs on NixOS, and this does not look like NixOS. Install NixOS (minimal) first."
[ "${NUSKU_EUID:-$EUID}" -ne 0 ] ||
    die "Run install.sh as your normal user, not root (it uses sudo for the build)."

# The installer's own tools (jq, git, lspci) come from the flake's pinned nixpkgs, so a minimal
# NixOS needs nothing installed first: re-run this script inside `nix shell`.
if [ "${NUSKU_IN_SHELL:-0}" != 1 ]; then
    export NUSKU_IN_SHELL=1
    exec nix shell --inputs-from "$NUSKU_ROOT" nixpkgs#jq nixpkgs#git nixpkgs#pciutils \
        --command bash "$NUSKU_ROOT/install.sh" "${args[@]}"
fi

log_init
trap 'die "command failed (exit $?): $BASH_COMMAND"' ERR

# Keep the sudo timestamp fresh during the build; stops when the installer exits.
SUDO_KEEPALIVE_PID=""
sudo_keepalive() {
    (
        trap - ERR
        while kill -0 "$$" 2>/dev/null; do
            sudo -n true 2>/dev/null || true
            sleep 50
        done
    ) </dev/null >/dev/null 2>&1 &
    SUDO_KEEPALIVE_PID=$!
}
# shellcheck disable=SC2329,SC2317  # invoked by the EXIT trap
cleanup() {
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# The run: mode first (a new host), host (rebuild a known one, no questions), apps or reconfigure.
mode=""
name=""
pick_mode() {
    local current
    current="$(detect_hostname)"
    if [ -n "$opt_host" ]; then
        mode=host name="$opt_host"
        host_exists "$name" ||
            die "No hosts/$name/settings.json. Known hosts: $(host_list). Run ./install.sh without --host to set up a new machine."
    elif [ "$opt_apps" -eq 1 ] || [ "$opt_reconfigure" -eq 1 ]; then
        mode=reconfigure name="$current"
        [ "$opt_apps" -eq 0 ] || mode=apps
        host_exists "$name" ||
            die "--$mode needs this machine's host (hosts/$name). Run ./install.sh first, or ./install.sh --host NAME to reinstall a known machine."
    elif host_exists "$current"; then
        mode=host name="$current"
        log_info "hosts/$current exists: rebuilding it without questions (./install.sh --reconfigure changes its settings)"
    else
        mode=first
    fi
}

preflight() {
    step "Preflight checks"
    # Try passwordless sudo first: `sudo -v` asks for a password unless every rule is NOPASSWD.
    sudo -n true 2>/dev/null || sudo -v ||
        die "The build needs sudo. Make sure your user can use sudo (is in the wheel group) and you typed the password correctly."
    sudo_keepalive
    catalogue_load
    # A new or reinstalled machine: what the NixOS installer set up for booting (LUKS, GRUB).
    # Read before the questions, where it gives GRUB's disk.
    case "$mode" in first | host) installer_probe ;; esac
}

step_questions() {
    step "Questions"
    case "$mode" in
        first)
            questions_menu first "$(detect_gpu)"
            name="${NUSKU_ANSWERS[HOSTNAME]}"
            ;;
        reconfigure)
            host_load "$name"
            questions_menu reconfigure "$(detect_gpu)"
            ;;
        apps)
            host_load "$name"
            apps_ask
            ;;
        host)
            host_load "$name"
            # The build makes this account without a password: it has to exist already.
            _q_check_user "${NUSKU_ANSWERS[USER]}" >/dev/null ||
                die "hosts/$name is for user ${NUSKU_ANSWERS[USER]}, who does not exist on this machine, so the build would make an account nobody can log in to. Create it first (sudo useradd -m ${NUSKU_ANSWERS[USER]} && sudo passwd ${NUSKU_ANSWERS[USER]}), or change \"user\" in hosts/$name/settings.json to your login."
            ;;
    esac
}

step_host() {
    step "Host $name"
    case "$mode" in
        first)
            answers_set STATE_VERSION "$(installer_state_version)"
            host_write "$name"
            host_copy_hw "$name"
            host_write_installer "$name"
            ;;
        reconfigure) host_write "$name" ;;
        apps) host_write_picks "$name" ;;
        host)
            host_copy_hw "$name"
            host_write_installer "$name"
            ;;
    esac
    host_commit "$name"
}

# Plain sentences for the summary, from the picks (nusku-arch's app hooks added these).
NOTES=()
collect_notes() {
    local apps=" ${NUSKU_ANSWERS[APPS]} " langs=" ${NUSKU_ANSWERS[LANGS]} "
    case "$apps" in *" docker "*) NOTES+=("You are in the docker group: that is root-equivalent.") ;; esac
    case "$apps" in *" sunshine "*) NOTES+=("Sunshine starts at login. Open https://localhost:47990 on this PC to create its login, then pair Moonlight with the PIN it shows.") ;; esac
    case "$apps" in *" calendar "*) NOTES+=("GNOME Calendar: after you log in, open Online Accounts to add Google or Nextcloud. Click the clock to open the calendar.") ;; esac
    case "$apps" in
        *" firefox "*)
            if [ -d "$HOME/.mozilla/firefox" ] ||
                { [ -e "$HOME/.config/mozilla/firefox/profiles.ini" ] && [ ! -L "$HOME/.config/mozilla/firefox/profiles.ini" ]; }; then
                NOTES+=("Firefox: you already had a profile (~/.mozilla/firefox or ~/.config/mozilla/firefox/profiles.ini), so Firefox may start unthemed or Home Manager may refuse to replace it; see README, Browsers and Obsidian.")
            fi
            ;;
    esac
    case "$langs" in *" rust "*) NOTES+=("Rust: the toolchain downloads in the background after you log in (systemctl --user status nusku-rustup).") ;; esac
    cat_any_flag browser "${NUSKU_ANSWERS[APPS]}" ||
        NOTES+=("No web browser is installed, so links will not open. Pick one with ./install.sh --apps.")
}

# record_checkout: where this checkout is, for nusku-rebuild and nusku-update (they run from the
# Nix store, so they can't find it themselves). Per machine, so it lives in the user's config,
# not in the repo. Written before the build, so it is there even if the build fails.
record_checkout() {
    local file="${XDG_CONFIG_HOME:-$HOME/.config}/nusku/repo"
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$NUSKU_ROOT" >"$file"
}

# Leftovers where Home Manager puts its files would stop the switch: move them aside, or stop.
step_home() {
    step "Your home"
    home_check
    [ -z "$HOME_BACKUP" ] ||
        NOTES+=("Files that were in Home Manager's way are in $HOME_BACKUP; copy back what you need.")
}

step_build() {
    step "Build"
    record_checkout
    # As the user (sudo only activates); see lib/sh/rebuild.sh.
    run_soft nusku_rebuild "$NUSKU_ROOT" "$name" ||
        die "The build failed (see above). hosts/$name is saved and committed, so fix the problem, then run: ./install.sh --host $name"
}

step_summary() {
    step "Summary"
    local gpu="${NUSKU_ANSWERS[GPU]}" n
    case "$gpu" in nvidia | hybrid-*) gpu="$gpu (${NUSKU_ANSWERS[NVIDIA]} driver)" ;; esac
    {
        printf '\nNusku is installed.\n'
        printf '  Host:    %s (hosts/%s)\n' "$name" "$name"
        printf '  GPU:     %s\n' "$gpu"
        printf '  Accent:  %s\n' "${NUSKU_ANSWERS[ACCENT]}"
        printf '  Apps:    %s apps, %s languages\n' "$(wc -w <<<"${NUSKU_ANSWERS[APPS]}")" "$(wc -w <<<"${NUSKU_ANSWERS[LANGS]}")"
        printf '  Log:     %s\n' "$NUSKU_LOG"
        if [ "$HOST_COMMITTED" -eq 1 ]; then
            printf '\nhosts/%s is committed here; push it (git push) so a reinstall can find it.\n' "$name"
        fi
        if [ "${#NOTES[@]}" -gt 0 ]; then
            printf '\nNotes:\n'
            for n in "${NOTES[@]}"; do
                printf '  - %s\n' "$n"
            done
        fi
        printf '\nNext step: Reboot to log in.\n'
    } | tee -a "$NUSKU_LOG" >&2
}

# tui_usable: status 0 when there is a terminal (or test input) to ask on.
tui_usable() {
    [ -n "${NUSKU_TUI_IN:-}" ] || { : </dev/tty; } 2>/dev/null
}

step_reboot() {
    if [ "$opt_no_reboot" -eq 1 ] || ! tui_usable; then
        return 0
    fi
    local reboot=1
    tui_open "${NUSKU_ANSWERS[ACCENT]}"
    if tui_choose "Reboot now?" "Nusku is ready. Log in after the reboot." 0 "Reboot now" "Later" && [ "$TUI_CHOICE" -eq 0 ]; then
        reboot=0
    fi
    tui_close
    [ "$reboot" -ne 0 ] || run sudo systemctl reboot
}

main() {
    pick_mode
    if [ "$mode" != host ] && ! tui_usable; then
        die "The questions need a terminal. To reinstall a known machine without them: ./install.sh --host NAME"
    fi
    preflight
    step_questions
    step_host
    collect_notes
    step_home
    step_build
    step_summary
    step_reboot
}

main
