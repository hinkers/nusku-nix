# nusku-wallpaper: the saved choices (~/.local/state/nusku/wallpapers) and swaybg, which draws
# them under niri. Stub niri / swaybg / pkill / setsid first on PATH.

setup() {
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    export NUSKU_WALLPAPERS="$BATS_TEST_TMPDIR/walls"
    export NUSKU_SDDM_BG_DIR="$BATS_TEST_TMPDIR/sddm"
    export NIRI_SOCKET="$BATS_TEST_TMPDIR/niri.sock"
    mkdir -p "$NUSKU_WALLPAPERS" "$NUSKU_SDDM_BG_DIR" "$BATS_TEST_TMPDIR/bin"
    for w in space.png a.png b.jpg; do echo "$w" >"$NUSKU_WALLPAPERS/$w"; done
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : >"$CALLS"
    for c in niri pkill; do
        printf '#!/bin/sh\necho "%s $*" >>"$CALLS"\n' "$c" >"$BATS_TEST_TMPDIR/bin/$c"
    done
    # setsid -f CMD...: record CMD and its arguments.
    printf '#!/bin/sh\n[ "$1" = -f ] && shift\necho "$*" >>"$CALLS"\n' >"$BATS_TEST_TMPDIR/bin/setsid"
    printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/bin/swaybg"
    chmod +x "$BATS_TEST_TMPDIR/bin/"*
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    state="$XDG_STATE_HOME/nusku"
}

@test "set all: saves *, links the current wallpaper, copies it for SDDM, starts swaybg" {
    run scripts/nusku-wallpaper set "$NUSKU_WALLPAPERS/a.png"
    [ "$status" -eq 0 ]
    [ "$(cat "$state/wallpapers")" = "*=$NUSKU_WALLPAPERS/a.png" ]
    [ "$(readlink "$state/current-wallpaper")" = "$NUSKU_WALLPAPERS/a.png" ]
    [ "$(cat "$NUSKU_SDDM_BG_DIR/background")" = a.png ]
    grep -qxF "pkill -x -u $(id -u) (\.)?swaybg(-wrapped)?" "$CALLS"
    grep -qxF "swaybg -o * -i $NUSKU_WALLPAPERS/a.png -m fill" "$CALLS"
}

@test "set one monitor: kept next to *, both passed to swaybg; SDDM keeps the * one" {
    scripts/nusku-wallpaper set "$NUSKU_WALLPAPERS/a.png"
    : >"$CALLS"
    run scripts/nusku-wallpaper set "$NUSKU_WALLPAPERS/b.jpg" DP-1
    [ "$status" -eq 0 ]
    [ "$(cat "$state/wallpapers")" = "$(printf '*=%s\nDP-1=%s' "$NUSKU_WALLPAPERS/a.png" "$NUSKU_WALLPAPERS/b.jpg")" ]
    [ "$(cat "$NUSKU_SDDM_BG_DIR/background")" = a.png ]
    grep -qxF "swaybg -o * -i $NUSKU_WALLPAPERS/a.png -m fill -o DP-1 -i $NUSKU_WALLPAPERS/b.jpg -m fill" "$CALLS"
}

@test "restore without a saved choice uses the default wallpaper" {
    run scripts/nusku-wallpaper restore
    [ "$status" -eq 0 ]
    [ "$(cat "$state/wallpapers")" = "*=$NUSKU_WALLPAPERS/space.png" ]
    grep -qxF "swaybg -o * -i $NUSKU_WALLPAPERS/space.png -m fill" "$CALLS"
}

@test "restore drops a missing per-monitor file and replaces a missing * with the default" {
    mkdir -p "$state"
    printf '*=%s\nHDMI-A-1=%s\n' "$BATS_TEST_TMPDIR/gone.png" "$BATS_TEST_TMPDIR/gone2.png" >"$state/wallpapers"
    run scripts/nusku-wallpaper restore
    [ "$status" -eq 0 ]
    [ "$(cat "$state/wallpapers")" = "*=$NUSKU_WALLPAPERS/space.png" ]
}

@test "outside a niri session: saves the choice, starts nothing" {
    unset NIRI_SOCKET
    run scripts/nusku-wallpaper set "$NUSKU_WALLPAPERS/a.png"
    [ "$status" -eq 0 ]
    [ "$(cat "$state/wallpapers")" = "*=$NUSKU_WALLPAPERS/a.png" ]
    ! grep -q swaybg "$CALLS" || false
}

@test "list prints the wallpapers" {
    run scripts/nusku-wallpaper list
    [ "$status" -eq 0 ]
    [ "$(wc -l <<<"$output")" -eq 3 ]
}
