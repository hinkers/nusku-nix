# rofi menus (power, keybinds, clipboard, the quick-settings pickers) and nusku-browser, with
# stub rofi / nmcli / bluetoothctl / niri / notify-send / ... first on PATH. Ported from
# nusku-arch test/unit/menus.bats (the clipboard menu and nusku-browser had no tests there).

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    export ROFI_ARGS="$BATS_TEST_TMPDIR/rofi-args"
    : >"$ROFI_ARGS"
    export NOTIFY_ARGS="$BATS_TEST_TMPDIR/notify-args"
    : >"$NOTIFY_ARGS"
    printf '#!/usr/bin/env bash\necho "$*" >>"$NOTIFY_ARGS"\n' >"$BATS_TEST_TMPDIR/bin/notify-send"
    # rofi stub: records its arguments and stdin; answers one pick per call from the queue file.
    cat >"$BATS_TEST_TMPDIR/bin/rofi" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$ROFI_ARGS"
cat >>"$ROFI_ARGS.stdin"
q="$ROFI_ARGS.queue"
[ -s "$q" ] || exit 1
read -r first rest <"$q"
echo "$rest" >"$q"
echo "$first"
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/rofi" "$BATS_TEST_TMPDIR/bin/notify-send"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : >"$CALLS"
}

picks() { echo "$*" >"$ROFI_ARGS.queue"; }

# --- nusku-menu-wifi ---------------------------------------------------------------------

net_setup() {
    # nmcli stub: Wi-Fi on; two APs for "Home" (keep the stronger), an open café, a saved "Work".
    cat >"$BATS_TEST_TMPDIR/bin/nmcli" <<'STUB'
#!/usr/bin/env bash
echo "nmcli $*" >>"$CALLS"
case "$*" in
    "radio wifi") echo enabled ;;
    *"dev wifi list"*)
        printf ' :Home:40:WPA2\n*:Home:70:WPA2\n :Cafe\\: Free:55:\n :Work:30:WPA2\n' ;;
    "-t -f NAME,TYPE con show") printf 'Work:802-11-wireless\nWired:802-3-ethernet\n' ;;
    "dev wifi connect"*) exit "${CONNECT_RC:-0}" ;;
esac
exit 0
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/nmcli"
}

@test "wifi menu: strongest first, one row per network, the connected one marked" {
    net_setup
    run scripts/nusku-menu-wifi
    [ "$(sed -n 1p "$ROFI_ARGS.stdin")" = "󰤥  Home  󰌾" ]
    [ "$(sed -n 2p "$ROFI_ARGS.stdin")" = "󰤥  Cafe: Free" ]
    [ "$(grep -c Home "$ROFI_ARGS.stdin")" -eq 1 ]
    grep -qF -- '-format i -a 0' "$ROFI_ARGS"
    grep -qF -- '-theme nusku' "$ROFI_ARGS"
}

@test "wifi menu: a saved network connects with its stored password" {
    net_setup
    picks 2
    run scripts/nusku-menu-wifi
    grep -qx 'nmcli con up id Work' "$CALLS"
    ! grep -q 'dev wifi connect' "$CALLS" || false
}

@test "wifi menu: a new secured network asks for the password" {
    net_setup
    picks 0 hunter2
    # Pick "Home" while not connected to it: drop the active marker from the stub.
    sed -i 's/\*:Home:70/ :Home:70/' "$BATS_TEST_TMPDIR/bin/nmcli"
    run scripts/nusku-menu-wifi
    grep -qF -- '-password' "$ROFI_ARGS"
    grep -qx 'nmcli dev wifi connect Home password hunter2' "$CALLS"
}

@test "wifi menu: a failed connect removes the half-made profile" {
    net_setup
    picks 1
    CONNECT_RC=1 run scripts/nusku-menu-wifi
    grep -qx 'nmcli dev wifi connect Cafe: Free' "$CALLS"
    grep -qx 'nmcli con delete id Cafe: Free' "$CALLS"
    grep -qF 'Could not connect to Cafe: Free' "$NOTIFY_ARGS"
}

@test "wifi menu: Esc does nothing" {
    net_setup
    run scripts/nusku-menu-wifi
    [ "$status" -eq 0 ]
    ! grep -qE 'wifi connect|con up' "$CALLS" || false
}

# --- nusku-menu-bluetooth ----------------------------------------------------------------

bt_setup() {
    cat >"$BATS_TEST_TMPDIR/bin/bluetoothctl" <<'STUB'
#!/usr/bin/env bash
echo "bluetoothctl $*" >>"$CALLS"
case "$*" in
    show) echo "	Powered: yes" ;;
    "devices Paired") printf 'Device AA:AA:AA:AA:AA:01 Buds\nDevice AA:AA:AA:AA:AA:02 Mouse\n' ;;
    devices) printf 'Device AA:AA:AA:AA:AA:01 Buds\nDevice AA:AA:AA:AA:AA:02 Mouse\nDevice BB:BB:BB:BB:BB:03 Speaker\nDevice CC:CC:CC:CC:CC:04 CC-CC-CC-CC-CC-04\n' ;;
    "info AA:AA:AA:AA:AA:01") printf '\tName: Buds\n\tIcon: audio-headset\n\tConnected: no\n' ;;
    "info AA:AA:AA:AA:AA:02") printf '\tName: Mouse\n\tIcon: input-mouse\n\tConnected: yes\n' ;;
    "info BB:BB:BB:BB:BB:03") printf '\tName: Speaker\n\tIcon: audio-card\n\tConnected: no\n' ;;
esac
exit 0
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/bluetoothctl"
}

@test "bluetooth menu: connected first, then paired, then new; unnamed devices hidden" {
    bt_setup
    run scripts/nusku-menu-bluetooth
    [ "$(sed -n 1p "$ROFI_ARGS.stdin")" = "󰍽  Mouse  ·  connected" ]
    [ "$(sed -n 2p "$ROFI_ARGS.stdin")" = "󰋋  Buds" ]
    [ "$(sed -n 3p "$ROFI_ARGS.stdin")" = "󰓃  Speaker  ·  pair" ]
    ! grep -q 'CC-CC' "$ROFI_ARGS.stdin" || false
    grep -qF -- '-format i -a 0' "$ROFI_ARGS"
}

@test "bluetooth menu: connect, disconnect and pair do the right thing" {
    bt_setup
    picks 1
    run scripts/nusku-menu-bluetooth
    grep -qx 'bluetoothctl connect AA:AA:AA:AA:AA:01' "$CALLS"
    picks 0
    run scripts/nusku-menu-bluetooth
    grep -qx 'bluetoothctl disconnect AA:AA:AA:AA:AA:02' "$CALLS"
    picks 2
    run scripts/nusku-menu-bluetooth
    grep -qx 'bluetoothctl pair BB:BB:BB:BB:BB:03' "$CALLS"
    grep -qx 'bluetoothctl trust BB:BB:BB:BB:BB:03' "$CALLS"
}

# Stubs for niri and systemctl (the keybind menu runs binds through `niri msg action`).
session_stubs() {
    export NIRI_ARGS="$BATS_TEST_TMPDIR/niri-args"
    : >"$NIRI_ARGS"
    printf '#!/usr/bin/env bash\necho "$*" >>"$NIRI_ARGS"\n' >"$BATS_TEST_TMPDIR/bin/niri"
    printf '#!/usr/bin/env bash\necho "systemctl $*" >>"$CALLS"\n' >"$BATS_TEST_TMPDIR/bin/systemctl"
    printf '#!/usr/bin/env bash\necho "hyprlock" >>"$CALLS"\n' >"$BATS_TEST_TMPDIR/bin/hyprlock"
    chmod +x "$BATS_TEST_TMPDIR/bin/niri" "$BATS_TEST_TMPDIR/bin/systemctl" "$BATS_TEST_TMPDIR/bin/hyprlock"
}

# --- nusku-menu-keybinds -----------------------------------------------------------------

# A niri config like the installed one: config.kdl includes a bind layout, apps.kdl and an
# optional local.kdl, relative to itself. NUSKU_NIRI_CONFIG points the menu at it.
kb_setup() {
    session_stubs
    local cfg="$BATS_TEST_TMPDIR/cfg"
    mkdir -p "$cfg/niri" "$cfg/nusku"
    export NUSKU_NIRI_CONFIG="$cfg/niri/config.kdl"
    cat >"$NUSKU_NIRI_CONFIG" <<'KDL'
layout {
    border { width 2; }
}
window-rule {
    match app-id=r#"^(kitty|foot)$"#
    open-floating true
}
include "binds.kdl"
include "../nusku/apps.kdl"
include optional=true "../nusku/local.kdl"
KDL
    cat >"$cfg/niri/binds.kdl" <<'KDL'
// Nusku binds
binds {
    Mod+Return hotkey-overlay-title="Open terminal" { spawn "kitty"; }
    Mod+Q repeat=false hotkey-overlay-title="Close window" { close-window; }
    Mod+Slash hotkey-overlay-title="Search keybinds" { spawn "nusku-menu-keybinds"; }
    Mod+Ctrl+Left hotkey-overlay-title="Narrower" { set-column-width "-5%"; }
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+0 { focus-workspace 10; }
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+0 { move-column-to-workspace 10; }
    Mod+WheelScrollDown cooldown-ms=150 hotkey-overlay-title="Next workspace" { focus-workspace-down; }
    XF86AudioMute allow-when-locked=true hotkey-overlay-title="Mute" { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    Mod+Shift+E { quit skip-confirmation=true; }
}
KDL
    cat >"$cfg/nusku/apps.kdl" <<'KDL'
binds {
    Super+Alt+E hotkey-overlay-title="Yazi \"files\"" { spawn "kitty" "-e" "yazi"; }
}
spawn-at-startup "nusku-obsidian-theme"
KDL
}

# The menu lines (rofi's stdin), without the padding.
listed() { sed -E 's/  +/|/' "$ROFI_ARGS.stdin"; }

@test "keybind menu lists description and keys, in config order, with includes" {
    kb_setup
    run scripts/nusku-menu-keybinds
    [ "$status" -eq 0 ]
    grep -qF -- '-theme nusku' "$ROFI_ARGS"
    [ "$(listed | head -3)" = "$(printf 'Open terminal|Super + Enter\nClose window|Super + Q\nSearch keybinds|Super + /')" ]
    listed | grep -qx 'Narrower|Super + Ctrl + Left'
    listed | grep -qx 'Mute|Mute key'
    listed | grep -qx 'Quit|Super + Shift + E'
    listed | grep -qx 'Yazi "files"|Super + Alt + E'
    [ ! -s "$NIRI_ARGS" ]
}

@test "keybind menu collapses workspace binds into one line per group" {
    kb_setup
    run scripts/nusku-menu-keybinds
    listed | grep -qx 'Go to workspace 1–10|Super + 1…0'
    listed | grep -qx 'Move window to workspace 1–10|Super + Shift + 1…0'
    ! listed | grep -q 'Focus workspace' || false
}

@test "keybind menu runs the picked bind through niri msg action" {
    kb_setup
    picks 0
    run scripts/nusku-menu-keybinds
    [ "$status" -eq 0 ]
    [ "$(cat "$NIRI_ARGS")" = 'msg action spawn -- kitty' ]
}

@test "keybind menu passes action arguments and properties" {
    kb_setup
    picks 3
    run scripts/nusku-menu-keybinds
    picks 7
    run scripts/nusku-menu-keybinds
    picks 8
    run scripts/nusku-menu-keybinds
    [ "$(cat "$NIRI_ARGS")" = "$(printf '%s\n' 'msg action set-column-width -- -5%' \
        'msg action spawn-sh -- wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle' \
        'msg action quit --skip-confirmation')" ]
}

@test "keybind menu: a workspace group opens a second list" {
    kb_setup
    picks 4 2
    run scripts/nusku-menu-keybinds
    [ "$status" -eq 0 ]
    grep -qF -- '-p Workspace' "$ROFI_ARGS"
    [ "$(cat "$NIRI_ARGS")" = 'msg action focus-workspace -- 10' ]
}

@test "keybind menu does not run a mouse wheel bind" {
    kb_setup
    picks 6
    run scripts/nusku-menu-keybinds
    [ "$status" -eq 0 ]
    listed | sed -n 7p | grep -q 'Next workspace'
    [ ! -s "$NIRI_ARGS" ]
}

@test "keybind menu: local.kdl replaces a key, and title=null hides it" {
    kb_setup
    cat >"$BATS_TEST_TMPDIR/cfg/nusku/local.kdl" <<'KDL'
binds {
    Mod+Return hotkey-overlay-title="My terminal" { spawn "foot"; }
    Mod+Q hotkey-overlay-title=null { close-window; }
    Mod+D { spawn "discord"; }
}
KDL
    picks 0
    run scripts/nusku-menu-keybinds
    [ "$(listed | head -1)" = 'My terminal|Super + Enter' ]
    ! listed | grep -q 'Close window' || false
    listed | grep -qx 'Run discord|Super + D'
    [ "$(cat "$NIRI_ARGS")" = 'msg action spawn -- foot' ]
}

@test "keybind menu Esc runs nothing" {
    kb_setup
    run scripts/nusku-menu-keybinds
    [ "$status" -eq 0 ]
    [ ! -s "$NIRI_ARGS" ]
}

@test "keybind menu without a niri config says so" {
    kb_setup
    export NUSKU_NIRI_CONFIG="$BATS_TEST_TMPDIR/nope/config.kdl"
    run scripts/nusku-menu-keybinds
    [ "$status" -eq 0 ]
    grep -q 'No niri config' "$NOTIFY_ARGS"
    [ ! -s "$ROFI_ARGS" ]
}

# --- nusku-menu-clipboard ----------------------------------------------------------------

clip_setup() {
    cat >"$BATS_TEST_TMPDIR/bin/cliphist" <<'STUB'
#!/usr/bin/env bash
echo "cliphist $*" >>"$CALLS"
case "$1" in
    list) printf '1\tfirst\n2\tsecond line\n' ;;
    decode) IFS=$'\t' read -r id text; printf 'decoded %s: %s' "$id" "$text" ;;
esac
STUB
    printf '#!/usr/bin/env bash\ncat >"$CALLS.copied"\n' >"$BATS_TEST_TMPDIR/bin/wl-copy"
    # rofi stub for a text pick (the entry contains a tab, which the queue stub would split)
    cat >"$BATS_TEST_TMPDIR/bin/rofi" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$ROFI_ARGS"
cat >>"$ROFI_ARGS.stdin"
[ -n "${CLIP_PICK:-}" ] || exit 1
printf '%s\n' "$CLIP_PICK"
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/cliphist" "$BATS_TEST_TMPDIR/bin/wl-copy" "$BATS_TEST_TMPDIR/bin/rofi"
}

@test "clipboard menu lists the history and copies the picked entry back" {
    clip_setup
    CLIP_PICK=$'2\tsecond line' run scripts/nusku-menu-clipboard
    [ "$status" -eq 0 ]
    [ "$(cat "$ROFI_ARGS.stdin")" = "$(printf '1\tfirst\n2\tsecond line')" ]
    grep -qF -- '-p Clipboard' "$ROFI_ARGS"
    grep -qF -- '-theme nusku' "$ROFI_ARGS"
    [ "$(cat "$CALLS.copied")" = "decoded 2: second line" ]
}

@test "clipboard menu Esc copies nothing" {
    clip_setup
    run scripts/nusku-menu-clipboard
    [ "$status" -eq 0 ]
    [ ! -e "$CALLS.copied" ]
    [ "$(cat "$CALLS")" = "cliphist list" ]
}

# --- nusku-browser (SUPER + B) -----------------------------------------------------------

# browser_setup DEFAULT LAUNCHABLE: xdg-mime answers DEFAULT for https; gtk-launch succeeds only
# for the desktop ids in LAUNCHABLE (space separated).
browser_setup() {
    export DEFAULT_BROWSER="$1" LAUNCHABLE="$2"
    cat >"$BATS_TEST_TMPDIR/bin/xdg-mime" <<'STUB'
#!/usr/bin/env bash
echo "xdg-mime $*" >>"$CALLS"
[ -z "$DEFAULT_BROWSER" ] || echo "$DEFAULT_BROWSER"
STUB
    cat >"$BATS_TEST_TMPDIR/bin/gtk-launch" <<'STUB'
#!/usr/bin/env bash
case " $LAUNCHABLE " in
    *" $1 "*) echo "gtk-launch $*" >>"$CALLS"; exit 0 ;;
esac
echo "gtk-launch: no such application $1" >&2
exit 1
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/xdg-mime" "$BATS_TEST_TMPDIR/bin/gtk-launch"
}

@test "nusku-browser opens the default browser (https handler) with the URL" {
    browser_setup brave-browser.desktop "brave-browser firefox"
    run scripts/nusku-browser https://nixos.org
    [ "$status" -eq 0 ]
    grep -qx 'xdg-mime query default x-scheme-handler/https' "$CALLS"
    [ "$(grep gtk-launch "$CALLS")" = "gtk-launch brave-browser https://nixos.org" ]
    [ ! -s "$NOTIFY_ARGS" ]
}

@test "nusku-browser falls back to an installed browser when the default is gone" {
    browser_setup gone.desktop "chromium-browser"
    run scripts/nusku-browser
    [ "$status" -eq 0 ]
    [ "$(grep gtk-launch "$CALLS")" = "gtk-launch chromium-browser" ]
}

@test "nusku-browser knows the NixOS desktop ids of the catalogue's browsers" {
    for id in firefox chromium-browser brave-browser librewolf; do
        : >"$CALLS"
        browser_setup "" "$id"
        run scripts/nusku-browser
        [ "$status" -eq 0 ]
        [ "$(grep gtk-launch "$CALLS")" = "gtk-launch $id" ]
    done
}

@test "nusku-browser without a browser warns and fails" {
    browser_setup "" ""
    run scripts/nusku-browser
    [ "$status" -eq 1 ]
    grep -qF 'No web browser' "$NOTIFY_ARGS"
    grep -qF -- '--apps' "$NOTIFY_ARGS"
}
