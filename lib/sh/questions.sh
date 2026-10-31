# shellcheck shell=bash
# Nusku - the install questions on one archinstall-style menu (lib/sh/tui.sh), ported from
# nusku-arch lib/questions.sh and the app picker of its lib/apps.sh. Not here: the AUR helper.
# New: the NixOS settings (host name, user, time zone, locale, keyboard, boot loader), read from
# the running machine and shown first, each one editable; PRIME bus IDs for a hybrid laptop.
# Needs lib/sh/log.sh, lib/sh/host.sh (answers, catalogue), lib/sh/detect.sh and lib/sh/tui.sh.
# Sourced, not executed. Test hook: NUSKU_ZONEINFO (default /etc/zoneinfo).
#
# Every setting is listed with its current value; Enter changes one, Install goes ahead, Esc asks
# whether to quit. Values start from the host's settings (--reconfigure), else from the machine.

NUSKU_ACCENTS=(rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire blue lavender)

# VALUE LABEL pairs for each question.
Q_GPU=(
    amd "AMD graphics"
    intel "Intel graphics"
    nvidia "NVIDIA graphics (desktop)"
    hybrid-intel "Intel + NVIDIA laptop"
    hybrid-amd "AMD + NVIDIA laptop"
    vm "Virtual machine"
)
Q_NVIDIA=(
    open "open — RTX 20xx / GTX 16xx and newer (recommended)"
    proprietary "proprietary — legacy 580 driver for GTX 900/10xx"
)
Q_BOOT=(
    systemd-boot "systemd-boot (UEFI)"
    grub "GRUB (BIOS)"
)

# q_label VALUE PAIRS...: the label of VALUE (VALUE itself when it is not listed).
q_label() {
    local v="$1"
    shift
    while [ "$#" -ge 2 ]; do
        if [ "$1" = "$v" ]; then
            printf '%s\n' "$2"
            return 0
        fi
        shift 2
    done
    printf '%s\n' "$v"
}

# q_needs_nvidia: status 0 when the chosen graphics include an NVIDIA card.
q_needs_nvidia() {
    case "${NUSKU_ANSWERS[GPU]:-}" in nvidia | hybrid-*) return 0 ;; esac
    return 1
}

q_hybrid() {
    case "${NUSKU_ANSWERS[GPU]:-}" in hybrid-*) return 0 ;; esac
    return 1
}

# questions_defaults SUGGESTED_GPU: fill in whatever is not answered yet, from the machine.
questions_defaults() {
    local loader device
    [ -n "${NUSKU_ANSWERS[HOSTNAME]+x}" ] || answers_set HOSTNAME "$(detect_hostname)"
    [ -n "${NUSKU_ANSWERS[USER]+x}" ] || answers_set USER "$(detect_user)"
    [ -n "${NUSKU_ANSWERS[TIMEZONE]+x}" ] || answers_set TIMEZONE "$(detect_timezone)"
    [ -n "${NUSKU_ANSWERS[LOCALE]+x}" ] || answers_set LOCALE "$(detect_locale)"
    [ -n "${NUSKU_ANSWERS[KEYMAP]+x}" ] || answers_set KEYMAP "$(detect_keymap)"
    if [ -z "${NUSKU_ANSWERS[BOOT_LOADER]+x}" ]; then
        read -r loader device <<<"$(detect_boot)"
        answers_set BOOT_LOADER "$loader"
        answers_set BOOT_DEVICE "${device:-}"
    fi
    [ -n "${NUSKU_ANSWERS[GPU]+x}" ] || answers_set GPU "$1"
    [ -n "${NUSKU_ANSWERS[PANELS]+x}" ] || answers_set PANELS "$(detect_panels "${NUSKU_ANSWERS[GPU]}")"
    [ -n "${NUSKU_ANSWERS[ACCENT]+x}" ] || answers_set ACCENT blue
    _q_gpu_fixup
}

# _q_gpu_fixup: an NVIDIA choice needs a driver and a hybrid one its bus IDs (detected when not
# known); other graphics must not keep them.
_q_gpu_fixup() {
    local kind id want
    if q_needs_nvidia; then
        [ -n "${NUSKU_ANSWERS[NVIDIA]:-}" ] || answers_set NVIDIA open
    else
        answers_set NVIDIA ""
    fi
    if ! q_hybrid; then
        answers_set PRIME_IGPU ""
        answers_set PRIME_NVIDIA ""
        return 0
    fi
    want=intel
    [ "${NUSKU_ANSWERS[GPU]}" != hybrid-amd ] || want=amd
    while read -r kind id; do
        case "$kind" in
            "$want") [ -n "${NUSKU_ANSWERS[PRIME_IGPU]:-}" ] || answers_set PRIME_IGPU "$id" ;;
            nvidia) [ -n "${NUSKU_ANSWERS[PRIME_NVIDIA]:-}" ] || answers_set PRIME_NVIDIA "$id" ;;
        esac
    done < <(detect_prime_ids)
    [ -n "${NUSKU_ANSWERS[PRIME_IGPU]+x}" ] || answers_set PRIME_IGPU ""
    [ -n "${NUSKU_ANSWERS[PRIME_NVIDIA]+x}" ] || answers_set PRIME_NVIDIA ""
}

# _q_pick KEY TITLE SUBTITLE PAIRS...: tui_choose over PAIRS; stores the value (Esc keeps it).
_q_pick() {
    local key="$1" title="$2" sub="$3" i=0 cur=0
    shift 3
    local -a values=() labels=()
    while [ "$#" -ge 2 ]; do
        values+=("$1")
        labels+=("$2")
        [ "$1" = "${NUSKU_ANSWERS[$key]:-}" ] && cur="$i"
        i=$((i + 1))
        shift 2
    done
    if tui_choose "$title" "$sub" "$cur" "${labels[@]}"; then
        answers_set "$key" "${values[$TUI_CHOICE]}"
    fi
}

# --- Typed answers ----------------------------------------------------------------------
# Each check prints why a value is refused and returns 1, or returns 0.

_q_check_hostname() {
    [[ "$1" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || {
        echo "Use lowercase letters, digits and dashes (up to 63), not starting or ending with a dash."
        return 1
    }
    ! host_exists "$1" || {
        echo "hosts/$1 already exists: reinstall it with ./install.sh --host $1"
        return 1
    }
}

_q_check_user() {
    id -u "$1" >/dev/null 2>&1 || {
        echo "There is no user $1 here: use the account you made when installing NixOS (it has your password)."
        return 1
    }
}

_q_check_word() {
    [[ "$1" =~ ^[^[:space:]]+$ ]] || {
        echo "Type a value without spaces."
        return 1
    }
}

_q_check_timezone() {
    _q_check_word "$1" || return 1
    local db="${NUSKU_ZONEINFO:-/etc/zoneinfo}"
    [ ! -d "$db" ] || [ -f "$db/$1" ] || {
        echo "Unknown time zone $1 (zones are named like Europe/Paris; see $db)."
        return 1
    }
}

_q_check_device() {
    [[ "$1" =~ ^/dev/[^[:space:]]+$ ]] || {
        echo "Type the whole disk, e.g. /dev/sda (not a partition such as /dev/sda1)."
        return 1
    }
}

_q_check_pci() {
    [[ "$1" =~ ^PCI:[0-9]+:[0-9]+:[0-9]+$ ]] || {
        echo "Write it as PCI:bus:device:function in decimal, e.g. PCI:1:0:0 (lspci shows 01:00.0)."
        return 1
    }
}

# _q_edit KEY TITLE SUBTITLE CHECK: type a new value; CHECK refuses a bad one with its message
# and asks again. Esc keeps the old value.
_q_edit() {
    local key="$1" title="$2" sub="$3" check="$4" value err=""
    value="${NUSKU_ANSWERS[$key]:-}"
    while tui_input "$title" "$sub" "$value" "$err"; do
        value="$TUI_INPUT"
        if err="$("$check" "$value")"; then
            answers_set "$key" "$value"
            return 0
        fi
    done
}

# --- Rows -------------------------------------------------------------------------------

_q_boot_label() {
    if [ "${NUSKU_ANSWERS[BOOT_LOADER]}" = grub ]; then
        printf 'GRUB on %s\n' "${NUSKU_ANSWERS[BOOT_DEVICE]:-(no disk)}"
    else
        q_label "${NUSKU_ANSWERS[BOOT_LOADER]}" "${Q_BOOT[@]}"
    fi
}

_q_prime_label() {
    if [ -n "${NUSKU_ANSWERS[PRIME_IGPU]}" ] && [ -n "${NUSKU_ANSWERS[PRIME_NVIDIA]}" ]; then
        printf '%s + %s\n' "${NUSKU_ANSWERS[PRIME_IGPU]}" "${NUSKU_ANSWERS[PRIME_NVIDIA]}"
    else
        printf 'not detected: enter them\n'
    fi
}

# _q_apps_summary: "N apps, M languages" for the menu.
_q_apps_summary() {
    local a l
    if [ -z "${NUSKU_ANSWERS[APPS]+x}" ]; then
        a="$(wc -w <<<"$(cat_starred)")"
        printf '%s usual picks\n' "$a"
        return 0
    fi
    a="$(wc -w <<<"${NUSKU_ANSWERS[APPS]}")"
    l="$(wc -w <<<"${NUSKU_ANSWERS[LANGS]:-}")"
    printf '%s app%s, %s language%s\n' "$a" "$([ "$a" = 1 ] || echo s)" "$l" "$([ "$l" = 1 ] || echo s)"
}

# _q_change ROW SUGGESTED_GPU: the screen that changes one row.
_q_change() {
    local a gpu
    local -a pairs=()
    case "$1" in
        hostname)
            _q_edit HOSTNAME "Host name" "Names this machine and its folder, hosts/<name>." _q_check_hostname
            ;;
        user)
            _q_edit USER "User" "Your login. It must be the account you made when installing NixOS." _q_check_user
            ;;
        timezone) _q_edit TIMEZONE "Time zone" "Like Europe/Paris or Australia/Brisbane." _q_check_timezone ;;
        locale) _q_edit LOCALE "Locale" "Language and formats, like en_AU.UTF-8." _q_check_word ;;
        keymap) _q_edit KEYMAP "Keyboard" "Keyboard layout, like us, uk or de." _q_check_word ;;
        boot)
            _q_pick BOOT_LOADER "Boot loader" "systemd-boot on a UEFI PC, GRUB on an older (BIOS) one." "${Q_BOOT[@]}"
            if [ "${NUSKU_ANSWERS[BOOT_LOADER]}" = grub ]; then
                _q_edit BOOT_DEVICE "GRUB disk" "The disk GRUB goes on, e.g. /dev/sda." _q_check_device
            else
                answers_set BOOT_DEVICE ""
            fi
            ;;
        gpu)
            gpu="${NUSKU_ANSWERS[GPU]}"
            for ((a = 0; a < ${#Q_GPU[@]}; a += 2)); do
                if [ "${Q_GPU[$a]}" = "$2" ]; then
                    pairs+=("${Q_GPU[$a]}" "${Q_GPU[$((a + 1))]} (detected)")
                else
                    pairs+=("${Q_GPU[$a]}" "${Q_GPU[$((a + 1))]}")
                fi
            done
            _q_pick GPU "Graphics" "Picks the right drivers. The detected one is marked." "${pairs[@]}"
            if [ "${NUSKU_ANSWERS[GPU]}" != "$gpu" ]; then
                answers_set PRIME_IGPU ""
                answers_set PRIME_NVIDIA ""
            fi
            _q_gpu_fixup
            ;;
        nvidia) _q_pick NVIDIA "NVIDIA driver" "Older cards (GTX 900/10xx) need the legacy one." "${Q_NVIDIA[@]}" ;;
        prime)
            a=Intel
            [ "${NUSKU_ANSWERS[GPU]}" != hybrid-amd ] || a=AMD
            _q_edit PRIME_IGPU "$a GPU bus ID" "The built-in $a graphics, as PCI:bus:device:function (lspci, in decimal)." _q_check_pci
            _q_edit PRIME_NVIDIA "NVIDIA GPU bus ID" "The NVIDIA card, as PCI:bus:device:function (lspci, in decimal)." _q_check_pci
            ;;
        accent)
            for a in "${NUSKU_ACCENTS[@]}"; do
                pairs+=("$a" "$(tui_swatch "$a")$a")
            done
            _q_pick ACCENT "Accent colour" "Catppuccin Mocha. Change it later here (--reconfigure)." "${pairs[@]}"
            ;;
        apps) apps_ask ;;
    esac
}

# _q_unready MODE: the row that must be fixed before installing (nothing when all is well).
_q_unready() {
    if [ "$1" = first ] && ! _q_check_hostname "${NUSKU_ANSWERS[HOSTNAME]}" >/dev/null; then
        echo hostname
    elif [ "${NUSKU_ANSWERS[BOOT_LOADER]}" = grub ] && [ -z "${NUSKU_ANSWERS[BOOT_DEVICE]}" ]; then
        echo boot
    elif q_hybrid && { [ -z "${NUSKU_ANSWERS[PRIME_IGPU]}" ] || [ -z "${NUSKU_ANSWERS[PRIME_NVIDIA]}" ]; }; then
        echo prime
    fi
}

# questions_menu MODE SUGGESTED_GPU: the main menu; MODE is first (a new host) or reconfigure (the
# host name is fixed). Returns when Install is picked, with every question answered (APPS falls
# back to the ★ apps if the list was never opened).
questions_menu() {
    local mode="$1" suggested="$2" cur=0 fix sub
    local -a rows=() lines=()
    questions_defaults "$suggested"
    sub="Check each setting, then pick Install."
    [ "$mode" = first ] || sub="Settings of ${NUSKU_ANSWERS[HOSTNAME]}. Check each one, then pick Install."
    tui_open "${NUSKU_ANSWERS[ACCENT]}"
    while :; do
        _tui_style "${NUSKU_ANSWERS[ACCENT]}"
        rows=() lines=()
        [ "$mode" != first ] || _q_row hostname "Host name" "${NUSKU_ANSWERS[HOSTNAME]}"
        _q_row user "User" "${NUSKU_ANSWERS[USER]}"
        _q_row timezone "Time zone" "${NUSKU_ANSWERS[TIMEZONE]}"
        _q_row locale "Locale" "${NUSKU_ANSWERS[LOCALE]}"
        _q_row keymap "Keyboard" "${NUSKU_ANSWERS[KEYMAP]}"
        _q_row boot "Boot loader" "$(_q_boot_label)"
        rows+=(-) lines+=(-)
        _q_row gpu "Graphics" "$(q_label "${NUSKU_ANSWERS[GPU]}" "${Q_GPU[@]}")"
        if q_needs_nvidia; then
            _q_row nvidia "NVIDIA driver" "${NUSKU_ANSWERS[NVIDIA]}"
        fi
        if q_hybrid; then
            _q_row prime "PRIME bus IDs" "$(_q_prime_label)"
        fi
        _q_row accent "Accent colour" "$(tui_swatch "${NUSKU_ANSWERS[ACCENT]}")${NUSKU_ANSWERS[ACCENT]}"
        _q_row apps "Apps" "$(_q_apps_summary)"
        rows+=(- install) lines+=(- "$TUI_ACCENT""Install$TUI_RESET")
        [ "$cur" -lt "${#rows[@]}" ] || cur=$((${#rows[@]} - 1))
        if ! tui_menu "Nusku setup" "$sub" \
            "$([ "$TUI_ASCII" = 1 ] && echo 'up/down move · enter changes · esc quits' || echo '↑↓ move · enter changes · esc quits')" \
            "$cur" "${lines[@]}"; then
            # Input closed (no terminal): nobody can answer, so stop rather than ask forever.
            [ "$TUI_KEY" != eof ] || _tui_interrupt
            if tui_choose "Leave the installer?" "Nothing has been changed yet." 0 "Keep going" "Quit"; then
                if [ "$TUI_CHOICE" -eq 1 ]; then
                    _tui_interrupt
                fi
            fi
            continue
        fi
        cur="$TUI_CHOICE"
        if [ "${rows[$cur]}" = install ]; then
            fix="$(_q_unready "$mode")"
            [ -n "$fix" ] || break
            _q_change "$fix" "$suggested"
        else
            _q_change "${rows[$cur]}" "$suggested"
        fi
    done
    tui_close
    if [ -z "${NUSKU_ANSWERS[APPS]+x}" ]; then
        answers_set APPS "$(cat_starred)"
        answers_set LANGS ""
    fi
}

# _q_row ROW LABEL VALUE: add a row to questions_menu's rows and lines.
_q_row() {
    rows+=("$1")
    lines+=("$(printf '%-16s %s' "$2" "$3")")
}

# --- The app list -----------------------------------------------------------------------
# One folding list (lib/sh/tui.sh): each group is a header with its apps indented underneath, and
# Languages is a group of its own right after Dev. Space ticks, Enter opens a group, Done saves,
# Esc keeps what was there before. Snapper (btrfs) is listed only when /home is btrfs.

# _apps_tree_build SEL LANGS: fill the tui_tree arrays (and _APPS_ROW, "app:ID", "lang:ID" or
# "group:ID" per row) from the catalogue, ticking the ids in the space-padded lists SEL and LANGS.
_APPS_ROW=()
_apps_tree_build() {
    local sel="$1" langs="$2" kind id label star row=0 on btrfs=false
    ! detect_home_btrfs || btrfs=true
    TUI_T_KIND=() TUI_T_LABEL=() TUI_T_PARENT=() TUI_T_ON=() TUI_T_OPEN=() _APPS_ROW=()
    # shellcheck disable=SC2016 # jq's $variables, not the shell's
    while IFS=$'\t' read -r kind id label star; do
        on=0
        case "$kind" in
            app) case "$sel" in *" $id "*) on=1 ;; esac ;;
            lang) case "$langs" in *" $id "*) on=1 ;; esac ;;
        esac
        [ "$star" != "*" ] || label="$label $TUI_MUTED$TUI_SYM_STAR$TUI_RESET"
        if [ "$kind" = g ]; then
            row=${#TUI_T_KIND[@]}
            TUI_T_KIND+=(g) TUI_T_PARENT+=("") _APPS_ROW+=("group:$id")
        else
            TUI_T_KIND+=(i) TUI_T_PARENT+=("$row") _APPS_ROW+=("$kind:$id")
        fi
        TUI_T_LABEL+=("$label") TUI_T_ON+=("$on") TUI_T_OPEN+=(0)
    done < <(_cat --argjson btrfs "$btrfs" '
        .apps as $apps | .langs as $langs | .groups[] |
        "g\t\(.id)\t\(.label)\t",
        (.id as $g | $apps[] | select(.group == $g and ($btrfs or ((.btrfs // false) | not)))
            | "app\t\(.id)\t\(.label)\t\(if .star then "*" else "" end)"),
        (if .id == "dev" then "g\tlanguages\tLanguages\t", ($langs[] | "lang\t\(.id)\t\(.label)\t") else empty end)')
}

# apps_ask: the folding list; stores APPS (catalogue order) and LANGS. Starts from the stored picks
# when the keys exist, else from the ★ apps and no languages. Esc keeps that start.
apps_ask() {
    local sel langs i id apps="" picked_langs=""
    if [ -n "${NUSKU_ANSWERS[APPS]+x}" ]; then
        sel=" ${NUSKU_ANSWERS[APPS]} "
    else
        sel=" $(cat_starred) "
    fi
    langs=" ${NUSKU_ANSWERS[LANGS]:-} "
    tui_open "${NUSKU_ANSWERS[ACCENT]:-blue}"
    _apps_tree_build "$sel" "$langs"
    if tui_tree "Optional apps" "$TUI_SYM_STAR marks the usual picks. Untick anything you do not want; pick Done to save."; then
        sel=" " langs=" "
        for i in "${!_APPS_ROW[@]}"; do
            if [ "${TUI_T_KIND[$i]}" != i ] || [ "${TUI_T_ON[$i]}" != 1 ]; then
                continue
            fi
            id="${_APPS_ROW[$i]}"
            case "$id" in
                app:*) sel="$sel${id#app:} " ;;
                lang:*) langs="$langs${id#lang:} " ;;
            esac
        done
    fi
    tui_close
    while IFS= read -r id; do
        case "$sel" in *" $id "*) apps="${apps:+$apps }$id" ;; esac
    done < <(_cat '.apps[].id')
    while IFS= read -r id; do
        case "$langs" in *" $id "*) picked_langs="${picked_langs:+$picked_langs }$id" ;; esac
    done < <(_cat '.langs[].id')
    answers_set APPS "$apps"
    answers_set LANGS "$picked_langs"
    log_info "Apps: ${apps:-none}"
    log_info "Languages: ${picked_langs:-none}"
}
