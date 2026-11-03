# lib/sh/questions.sh: the settings menu, with keys fed from a file. Ported from nusku-arch
# test/unit/questions.bats (the AUR helper row is gone; the NixOS system rows come first).
# Rows of a first run on an Intel machine:
#   0 Host name  1 User  2 Time zone  3 Locale  4 Keyboard  5 Boot loader  (divider)
#   7 Graphics  8 Accent colour  9 Apps  (divider)  11 Install
# NVIDIA adds "NVIDIA driver" after Graphics, a hybrid laptop also "PRIME bus IDs".

setup() {
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    unset NUSKU_LOG NUSKU_STEP
    export NUSKU_TUI_IN="$BATS_TEST_TMPDIR/keys" NUSKU_TUI_OUT="$BATS_TEST_TMPDIR/screen"
    export NUSKU_ROOT="$BATS_TEST_TMPDIR/root"
    mkdir -p "$NUSKU_ROOT/lib" "$NUSKU_ROOT/hosts"
    cp lib/palette.nix "$NUSKU_ROOT/lib/"
    NUSKU_CATALOGUE="$(cat test/fixtures/catalogue.json)"
    export NUSKU_CATALOGUE
    export NUSKU_HOSTNAME=nixos NUSKU_USER=tester NUSKU_TIMEZONE=Australia/Brisbane \
        NUSKU_LOCALE=en_AU.UTF-8 NUSKU_KEYMAP=us NUSKU_HOME_FSTYPE=ext4
    export NUSKU_EFI_DIR="$BATS_TEST_TMPDIR" NUSKU_DRM_DIR="$BATS_TEST_TMPDIR/drm"
    export NUSKU_ZONEINFO="$BATS_TEST_TMPDIR/zoneinfo"
    mkdir -p "$NUSKU_ZONEINFO/Europe"
    : >"$NUSKU_ZONEINFO/Europe/Paris"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    mkdir -p "$STUBS"
    export LSPCI_OUT="$BATS_TEST_TMPDIR/lspci"
    printf '00:02.0 VGA compatible controller: Intel Corporation Iris Xe Graphics\n' >"$LSPCI_OUT"
    printf '#!/bin/sh\ncat "$LSPCI_OUT"\n' >"$STUBS/lspci"
    printf '#!/bin/sh\necho none\nexit 1\n' >"$STUBS/systemd-detect-virt"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
}

# menu KEYS SETUP [MODE]: run questions_menu (MODE first or reconfigure) after SETUP; print the answers.
menu() {
    printf "$1" >"$NUSKU_TUI_IN"
    bash -c 'set -Eeuo pipefail
        source lib/sh/log.sh; source lib/sh/host.sh; source lib/sh/detect.sh; source lib/sh/tui.sh; source lib/sh/questions.sh
        '"$2"'; questions_menu '"${3:-first}"' "$(detect_gpu)" >/dev/null 2>&1
        for k in HOSTNAME USER TIMEZONE LOCALE KEYMAP BOOT_LOADER BOOT_DEVICE GPU NVIDIA PRIME_IGPU PRIME_NVIDIA PANELS ACCENT APPS LANGS; do
            printf "%s=[%s] " "$k" "$(answers_get "$k")"
        done'
}

screen() { sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$NUSKU_TUI_OUT"; }

# keys: \e[B down, \e[A up, \e[F end (Install, or Done in the app list), \n enter, \e esc, \x7f backspace.
DOWN6='\e[B\e[B\e[B\e[B\e[B\e[B'
BS5='\x7f\x7f\x7f\x7f\x7f'

@test "Install straight away takes what was detected and the defaults" {
    run menu '\e[F\n' ':'
    [ "$status" -eq 0 ]
    [ "$output" = "HOSTNAME=[nixos] USER=[tester] TIMEZONE=[Australia/Brisbane] LOCALE=[en_AU.UTF-8] KEYMAP=[us] BOOT_LOADER=[systemd-boot] BOOT_DEVICE=[] GPU=[intel] NVIDIA=[] PRIME_IGPU=[] PRIME_NVIDIA=[] PANELS=[[]] ACCENT=[blue] APPS=[neovim gh claude-code firefox discord obsidian spotify vlc] LANGS=[] " ]
    screen | grep -qE 'Host name +nixos'
    screen | grep -qE 'Time zone +Australia/Brisbane'
    screen | grep -qE 'Boot loader +systemd-boot \(UEFI\)'
    screen | grep -qE 'Graphics +Intel graphics'
    screen | grep -qE 'Apps +8 usual picks'
    ! screen | grep -q 'AUR' || false
}

@test "the detected graphics are marked in the list" {
    run menu "$DOWN6"'\n\e\e[F\n' ':'
    [ "$status" -eq 0 ]
    screen | grep -qF 'Intel graphics (detected)'
}

@test "picking NVIDIA adds the driver row; picking Intel again drops it" {
    # Graphics: intel (2nd) -> down to nvidia (3rd).
    run menu "$DOWN6"'\n\e[B\n\e[F\n' ':'
    [[ "$output" == *"GPU=[nvidia] NVIDIA=[open] PRIME_IGPU=[] "* ]]
    screen | grep -qE 'NVIDIA driver +open'
    run menu "$DOWN6"'\n\e[A\n\e[F\n' 'answers_set GPU nvidia; answers_set NVIDIA proprietary'
    [[ "$output" == *"GPU=[intel] NVIDIA=[] "* ]]
}

@test "a hybrid laptop gets the detected PRIME bus IDs and its laptop screen" {
    printf '%s\n' '00:02.0 VGA compatible controller: Intel Corporation Iris Xe Graphics' \
        '01:00.0 3D controller: NVIDIA Corporation GA107M' >"$LSPCI_OUT"
    mkdir -p "$NUSKU_DRM_DIR/card1-eDP-1"
    printf '1920x1200\n' >"$NUSKU_DRM_DIR/card1-eDP-1/modes"
    run menu '\e[F\n' ':'
    [[ "$output" == *'GPU=[hybrid-intel] NVIDIA=[open] PRIME_IGPU=[PCI:0:2:0] PRIME_NVIDIA=[PCI:1:0:0] PANELS=[[{"output":"eDP-1","scale":1.25}]] '* ]]
    screen | grep -qE 'PRIME bus IDs +PCI:0:2:0 \+ PCI:1:0:0'
}

@test "hybrid graphics without detected bus IDs: Install asks for them first" {
    printf '%s\n' '00:02.0 VGA compatible controller: Intel Corporation Iris Xe Graphics' \
        '01:00.0 3D controller: NVIDIA Corporation GA107M' >"$LSPCI_OUT"
    # Graphics: hybrid-intel (4th) -> hybrid-amd (5th); no AMD card was found, so Install opens
    # the integrated GPU's bus ID (typed), then the NVIDIA one (kept); then Install again.
    run menu "$DOWN6"'\n\e[B\n\e[F\nPCI:5:0:0\n\n\n' ':'
    [ "$status" -eq 0 ]
    [[ "$output" == *"GPU=[hybrid-amd] NVIDIA=[open] PRIME_IGPU=[PCI:5:0:0] PRIME_NVIDIA=[PCI:1:0:0] "* ]]
}

@test "a bus ID must look like PCI:bus:device:function" {
    # Install opens the integrated GPU's bus ID: a wrong one is refused with a message, Esc leaves.
    run menu '\e[F\n05:00.0\n\e\e' 'answers_set GPU hybrid-amd; answers_set PRIME_NVIDIA PCI:1:0:0'
    [ "$status" -eq 1 ]
    screen | grep -qF 'Write it as PCI:bus:device:function'
}

@test "accent is changed in place" {
    # Accent colour (8th row): blue (13th) -> sapphire (12th).
    run menu "$DOWN6"'\e[B\n\e[A\n\e[F\n' ':'
    [[ "$output" == *"ACCENT=[sapphire] "* ]]
}

@test "the host name is typed in; a bad one is refused with a message" {
    run menu '\n'"$BS5"'laptop\n\e[F\n' ':'
    [[ "$output" == "HOSTNAME=[laptop] "* ]]
    run menu '\n'"$BS5"'Bad_Name\n\e\e[F\n' ':'
    [[ "$output" == "HOSTNAME=[nixos] "* ]]
    screen | grep -qF 'lowercase letters, digits and dashes'
}

@test "a host name already in hosts/ is refused (reinstall it with --host)" {
    mkdir -p "$NUSKU_ROOT/hosts/laptop"
    : >"$NUSKU_ROOT/hosts/laptop/settings.json"
    run menu '\n'"$BS5"'laptop\n\e\e[F\n' ':'
    [[ "$output" == "HOSTNAME=[nixos] "* ]]
    screen | grep -qF 'hosts/laptop already exists: reinstall it with ./install.sh --host laptop'
}

@test "the user must be an existing account" {
    run menu '\e[B\n\x7f\x7f\x7f\x7f\x7f\x7fnosuchuser\n\e\e[F\n' ':'
    [[ "$output" == *"USER=[tester] "* ]]
    screen | grep -qF 'There is no user nosuchuser here'
}

@test "time zone: typed in, checked against the zone database" {
    run menu '\e[B\e[B\n\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7fMars/Base\n\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7fEurope/Paris\n\e[F\n' ':'
    [[ "$output" == *"TIMEZONE=[Europe/Paris] "* ]]
    screen | grep -qF 'Unknown time zone Mars/Base'
}

@test "keyboard: an xkb layout; a console keymap name (uk) is refused with the xkb one (gb)" {
    run menu '\e[B\e[B\e[B\e[B\n\x7f\x7fuk\n\x7f\x7fde-latin1\n\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7fus,de\n\e[F\n' ':'
    [[ "$output" == *"KEYMAP=[us,de] "* ]]
    screen | grep -qF 'uk is a console keymap name: type the keyboard layout, gb'
    screen | grep -qF 'de-latin1 is a console keymap name: type the keyboard layout, de'
    run menu '\e[B\e[B\e[B\e[B\n\x7f\x7fgb\n\e[F\n' ':'
    [[ "$output" == *"KEYMAP=[gb] "* ]]
    run menu '\e[B\e[B\e[B\e[B\n\x7f\x7fDE\n\x7f\x7fde\n\e[F\n' ':'
    [[ "$output" == *"KEYMAP=[de] "* ]]
    screen | grep -qF 'Type an xkb layout'
}

@test "boot loader: GRUB asks for its disk; systemd-boot clears it" {
    run menu '\e[B\e[B\e[B\e[B\e[B\n\e[B\n/dev/sda\n\e[F\n' ':'
    [[ "$output" == *"BOOT_LOADER=[grub] BOOT_DEVICE=[/dev/sda] "* ]]
    screen | grep -qE 'Boot loader +GRUB on /dev/sda'
    run menu '\e[B\e[B\e[B\e[B\e[B\n\e[A\n\e[F\n' 'answers_set BOOT_LOADER grub; answers_set BOOT_DEVICE /dev/sda'
    [[ "$output" == *"BOOT_LOADER=[systemd-boot] BOOT_DEVICE=[] "* ]]
}

@test "reconfigure: the saved answers are the starting point; the host name is fixed" {
    run menu '\e[F\n' 'answers_set HOSTNAME laptop; answers_set GPU amd; answers_set ACCENT mauve; answers_set APPS gimp; answers_set LANGS go' reconfigure
    [[ "$output" == "HOSTNAME=[laptop] "*"GPU=[amd] "*"ACCENT=[mauve] APPS=[gimp] LANGS=[go] " ]]
    screen | grep -qE 'Apps +1 app, 1 language$'
    ! screen | grep -q 'Host name' || false
}

@test "Apps opens the folding app list from the menu" {
    # Apps is the 10th row; in the list, tick all of Dev's Languages group (2nd row), Done, Install.
    run menu "$DOWN6"'\e[B\e[B\n\e[B \e[F\n\e[F\n' ':'
    [[ "$output" == *"LANGS=[python php gdscript js rust go cpp csharp java lua] " ]]
}

@test "the app list: ★ usual picks, apps saved in catalogue order" {
    # Tick every Gaming app (6th group) and untick every Dev app, then Done.
    run bash -c 'set -Eeuo pipefail; source lib/sh/log.sh; source lib/sh/host.sh; source lib/sh/detect.sh; source lib/sh/tui.sh; source lib/sh/questions.sh
        printf "\e[B\e[B\e[B\e[B\e[B\e[B \e[H  \e[F\n" >"$NUSKU_TUI_IN"
        answers_set APPS "vlc neovim"
        apps_ask >/dev/null 2>&1; answers_get APPS'
    [ "$output" = "vlc steam lutris heroic parsec sunshine moonlight gamemode mangohud protonup wine osrs" ]
    grep -qF 'Gaming' "$NUSKU_TUI_OUT"
    grep -qF '★ marks the usual picks' "$NUSKU_TUI_OUT"
}

@test "Snapper is offered only when /home is its own btrfs mount" {
    list() {
        NUSKU_HOME_FSTYPE="$1" bash -c 'source lib/sh/log.sh; source lib/sh/host.sh; source lib/sh/detect.sh; source lib/sh/tui.sh; source lib/sh/questions.sh
            _tui_style; _apps_tree_build " " " "; printf "%s\n" "${_APPS_ROW[@]}"'
    }
    run list ext4
    ! grep -qx app:snapper <<<"$output" || false
    grep -qx app:gparted <<<"$output"
    run list btrfs
    grep -qx app:snapper <<<"$output"
}

@test "Esc asks first: Keep going stays, Quit cancels" {
    run menu '\e\n\e[F\n' ':'
    [ "$status" -eq 0 ]
    [[ "$output" == "HOSTNAME=[nixos] "* ]]
    run menu '\e\e[B\n' ':'
    [ "$status" -eq 1 ]
}

@test "running out of input cancels instead of waiting forever" {
    run timeout 10 bash -c "$(declare -f menu); menu '' ':'"
    [ "$status" -eq 1 ]
}
