# shellcheck shell=bash
# Nusku - what the installer reads from the running machine, as defaults for the settings menu.
# Sourced, not executed. Nothing here fails: an unreadable probe gives the usual default.
# Test hooks (each value can be set from the environment): NUSKU_HOSTNAME, NUSKU_USER,
# NUSKU_TIMEZONE (else NUSKU_LOCALTIME, default /etc/localtime), NUSKU_LOCALE, NUSKU_KEYMAP,
# NUSKU_EFI_DIR (default /sys/firmware/efi), NUSKU_ROOT_DISK, NUSKU_DRM_DIR (default
# /sys/class/drm), NUSKU_HOME_FSTYPE; lspci and systemd-detect-virt are found on PATH.

# _detect_virt: hypervisor name from systemd-detect-virt --vm ("none" on bare metal or if unavailable).
_detect_virt() {
    local v
    v="$(systemd-detect-virt --vm 2>/dev/null || true)"
    printf '%s\n' "${v:-none}"
}

# _detect_gpus: lspci's graphics lines (VGA, 3D and display controllers); nothing without lspci.
_detect_gpus() {
    lspci 2>/dev/null | grep -Ei 'vga|3d|display' || true
}

# detect_gpu: amd intel nvidia hybrid-intel hybrid-amd or vm (nusku-arch gpu_suggest). A default
# for the menu only; falls back to "amd".
detect_gpu() {
    local pci nv=0 amd=0 intel=0
    if [ "$(_detect_virt)" != "none" ]; then
        echo vm
        return 0
    fi
    pci="$(_detect_gpus)"
    case "$pci" in *[Nn][Vv][Ii][Dd][Ii][Aa]*) nv=1 ;; esac
    case "$pci" in *AMD* | *ATI* | *Radeon*) amd=1 ;; esac
    case "$pci" in *[Ii]ntel*) intel=1 ;; esac
    if [ "$nv" -eq 1 ] && [ "$intel" -eq 1 ]; then
        echo hybrid-intel
    elif [ "$nv" -eq 1 ] && [ "$amd" -eq 1 ]; then
        echo hybrid-amd
    elif [ "$nv" -eq 1 ]; then
        echo nvidia
    elif [ "$intel" -eq 1 ]; then
        echo intel
    else
        echo amd
    fi
}

# detect_prime_ids: "intel|amd|nvidia PCI:bus:device:function" for the first graphics card of each
# kind, in decimal as hardware.nvidia.prime wants (lspci's 0a:00.0 is PCI:10:0:0).
detect_prime_ids() {
    local addr rest kind bus dev fn seen=" "
    while read -r addr rest; do
        case "$rest" in
            *[Nn][Vv][Ii][Dd][Ii][Aa]*) kind=nvidia ;;
            *[Ii]ntel*) kind=intel ;;
            *AMD* | *ATI* | *Radeon*) kind=amd ;;
            *) continue ;;
        esac
        case "$seen" in *" $kind "*) continue ;; esac
        seen="$seen$kind "
        case "$addr" in *:*:*) addr="${addr#*:}" ;; esac # drop a PCI domain (0000:01:00.0)
        bus="${addr%%:*}" dev="${addr#*:}" fn="${addr##*.}"
        dev="${dev%%.*}"
        printf '%s PCI:%d:%d:%d\n' "$kind" "0x$bus" "0x$dev" "0x$fn"
    done < <(_detect_gpus)
}

# detect_panels GPU: JSON list of the built-in panels that need a scale: 1.25 for each 1920x1200
# or 1920x1080 laptop screen (eDP), where Hyprland's auto scale picks 1.5 and leaves only 1280x800
# of room (nusku-arch gpu_panel_lua). Virtual machines get none.
detect_panels() {
    local dir="${NUSKU_DRM_DIR:-/sys/class/drm}" conn name mode out=""
    if [ "${1:-}" != vm ]; then
        for conn in "$dir"/card*-eDP-*; do
            [ -r "$conn/modes" ] || continue
            mode="$(head -n1 "$conn/modes")"
            name="${conn##*/}"
            name="${name#card*-}" # card1-eDP-1 -> eDP-1
            case "$mode" in
                1920x1200 | 1920x1080) out="${out:+$out,}{\"output\":\"$name\",\"scale\":1.25}" ;;
            esac
        done
    fi
    printf '[%s]\n' "$out"
}

# detect_boot: "systemd-boot" on a UEFI machine, else "grub DISK" with the disk / is on.
detect_boot() {
    local src disk
    if [ -d "${NUSKU_EFI_DIR:-/sys/firmware/efi}" ]; then
        echo systemd-boot
        return 0
    fi
    disk="${NUSKU_ROOT_DISK:-}"
    if [ -z "$disk" ]; then
        src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
        disk="$(lsblk -n -d -o PKNAME "$src" 2>/dev/null || true)"
        disk="${disk:+/dev/$disk}"
    fi
    printf 'grub %s\n' "$disk"
}

detect_hostname() {
    local h="${NUSKU_HOSTNAME:-}"
    [ -n "$h" ] || h="$(cat /proc/sys/kernel/hostname 2>/dev/null || true)"
    printf '%s\n' "${h:-nixos}"
}

# detect_user: the account running the installer (it must not be root).
detect_user() {
    printf '%s\n' "${NUSKU_USER:-$(id -un)}"
}

detect_timezone() {
    local tz="${NUSKU_TIMEZONE:-}"
    [ -n "$tz" ] || tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
    if [ -z "$tz" ]; then
        tz="$(readlink "${NUSKU_LOCALTIME:-/etc/localtime}" 2>/dev/null || true)"
        tz="${tz#*zoneinfo/}"
    fi
    printf '%s\n' "${tz:-UTC}"
}

# _detect_localectl FIELD: a value from `localectl status`. "n/a", "(unset)" (a fresh NixOS
# prints "VC Keymap: (unset)") and any other "(...)" placeholder count as none.
_detect_localectl() {
    local v
    v="$(localectl status 2>/dev/null | sed -n "s/^ *$1: *//p" | head -n1)"
    case "$v" in
        n/a | "("*")") ;;
        *) printf '%s' "$v" ;;
    esac
}

detect_locale() {
    local l="${NUSKU_LOCALE:-}"
    [ -n "$l" ] || { l="$(_detect_localectl 'System Locale')" && l="${l#LANG=}"; }
    [ -n "$l" ] || l="${LANG:-}"
    printf '%s\n' "${l:-en_US.UTF-8}"
}

detect_keymap() {
    local k="${NUSKU_KEYMAP:-}"
    [ -n "$k" ] || k="$(_detect_localectl 'VC Keymap')"
    [ -n "$k" ] || k="$(_detect_localectl 'X11 Layout')"
    printf '%s\n' "${k:-us}"
}

# detect_home_btrfs: status 0 when /home is its own btrfs mount (where Snapper's snapshots go;
# modules/nixos/apps.nix skips Snapper otherwise).
detect_home_btrfs() {
    [ "${NUSKU_HOME_FSTYPE:-$(findmnt -n -o FSTYPE --mountpoint /home 2>/dev/null || true)}" = btrfs ]
}
