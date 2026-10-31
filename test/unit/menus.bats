# rofi pickers behind the quick-settings split buttons (and the bar's right-click), with stub
# rofi / nmcli / bluetoothctl / notify-send. Ported from nusku-arch test/unit/menus.bats; the
# power and keybind menus' tests come with those menus.

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
