# Quick settings: nusku-quick, which the Nusku shell's panel (config/quickshell/nusku) calls for
# the toggles it doesn't read natively.

@test "nusku-quick: unknown toggle fails, power status compares the profile" {
    run scripts/nusku-quick status nope
    [ "$status" -eq 2 ]
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/sh\necho balanced\n' >"$BATS_TEST_TMPDIR/bin/powerprofilesctl"
    chmod +x "$BATS_TEST_TMPDIR/bin/powerprofilesctl"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick status power-balanced
    [ "$output" = true ]
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick status power-performance
    [ "$output" = false ]
}

@test "nusku-quick: night light starts and stops wlsunset at a fixed temperature" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : >"$CALLS"
    for c in wlsunset pkill setsid; do
        printf '#!/bin/sh\necho "%s $*" >>"$CALLS"\n' "$c" >"$BATS_TEST_TMPDIR/bin/$c"
    done
    printf '#!/bin/sh\nexit "${PGREP_RC:-1}"\n' >"$BATS_TEST_TMPDIR/bin/pgrep"
    chmod +x "$BATS_TEST_TMPDIR/bin/"*
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick toggle night
    [ "$status" -eq 0 ]
    grep -qx 'setsid -f wlsunset -t 4000 -T 4001 -S 06:00 -s 18:00' "$CALLS"
    PGREP_RC=0 PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick toggle night
    grep -qx 'pkill -x wlsunset' "$CALLS"
}

@test "nusku-quick: usage without arguments" {
    run scripts/nusku-quick
    [ "$status" -eq 2 ]
    [[ "$output" == *"nusku-quick status NAME"* ]]
}

@test "nusku-quick: caffeine stops and starts the swayidle service" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : >"$CALLS"
    # is-active answers from IDLE_RC; every other call is recorded.
    printf '#!/bin/sh\ncase "$*" in *is-active*) exit "${IDLE_RC:-0}" ;; esac\necho "systemctl $*" >>"$CALLS"\n' \
        >"$BATS_TEST_TMPDIR/bin/systemctl"
    chmod +x "$BATS_TEST_TMPDIR/bin/systemctl"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick status caffeine
    [ "$output" = false ]
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick toggle caffeine
    grep -qx 'systemctl --user stop swayidle' "$CALLS"
    IDLE_RC=3 PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick status caffeine
    [ "$output" = true ]
    IDLE_RC=3 PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick toggle caffeine
    grep -qx 'systemctl --user start swayidle' "$CALLS"
}

@test "every toggle the shell reads through nusku-quick is one it knows" {
    names=$(sed -n 's/.*names: \[\(.*\)\].*/\1/p' config/quickshell/nusku/services/Quick.qml | tr -d '",')
    [ "$(wc -w <<<"$names")" -eq 5 ]
    for n in $names; do
        run scripts/nusku-quick status "$n"
        [ "$status" -ne 2 ] || { echo "unknown toggle: $n"; false; }
    done
}

@test "nusku-quick: Do Not Disturb goes through the Nusku shell (qs ipc)" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : >"$CALLS"
    printf '#!/bin/sh\necho "qs $*" >>"$CALLS"\necho true\n' >"$BATS_TEST_TMPDIR/bin/qs"
    chmod +x "$BATS_TEST_TMPDIR/bin/qs"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick status dnd
    [ "$output" = true ]
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick toggle dnd
    [ "$(cat "$CALLS")" = "$(printf 'qs -c nusku ipc call notifications dnd\nqs -c nusku ipc call notifications toggleDnd')" ]
}
