# Quick settings: nusku-swaync-config writes the panel config per machine (run by the swaync unit
# before swaync starts; modules/home/panels.nix); nusku-quick drives the toggles.
# Ported from nusku-arch test/unit/swaync.bats (there lib/swaync.sh did the writing).

setup() {
    export NUSKU_BACKLIGHT_DIR="$BATS_TEST_TMPDIR/backlight"
    mkdir -p "$NUSKU_BACKLIGHT_DIR"
    OUT="$BATS_TEST_TMPDIR/swaync/config.json"
}

write() { scripts/nusku-swaync-config config/swaync/config.template.json "$OUT"; }

power_labels() { jq -r '."widget-config"."buttons-grid#power".actions[].command' "$OUT" | awk '{print $NF}' | tr '\n' ' '; }

@test "the template is valid JSON and every widget has its config" {
    jq -e . config/swaync/config.template.json >/dev/null
    run jq -r '. as $r | .widgets[] | select(. != "notifications") | select($r."widget-config"[.] == null)' \
        config/swaync/config.template.json
    [ -z "$output" ]
}

@test "the template calls scripts by name (from the Nix profile), not from ~/.local/bin" {
    ! grep -qF '.local/bin' config/swaync/config.template.json
    grep -qF '"command": "nusku-quick toggle wifi"' config/swaync/config.template.json
}

@test "laptop: brightness slider uses the machine's backlight device" {
    mkdir "$NUSKU_BACKLIGHT_DIR/amdgpu_bl1"
    NUSKU_POWER_PROFILES="power-saver balanced performance" run write
    [ "$status" -eq 0 ]
    jq -e '.widgets | index("backlight")' "$OUT" >/dev/null
    [ "$(jq -r '."widget-config".backlight.device' "$OUT")" = amdgpu_bl1 ]
    [ "$(power_labels)" = "power-saver balanced performance " ]
}

@test "desktop: no backlight, no brightness slider" {
    NUSKU_POWER_PROFILES="power-saver balanced performance" run write
    [ "$status" -eq 0 ]
    ! jq -e '.widgets | index("backlight")' "$OUT" >/dev/null
    jq -e '."widget-config".backlight == null' "$OUT" >/dev/null
}

@test "power modes the machine lacks are left out" {
    NUSKU_POWER_PROFILES="power-saver balanced" run write
    [ "$(power_labels)" = "power-saver balanced " ]
}

@test "power profiles are read from powerprofilesctl" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/sh\nprintf "  performance:\n    Driver: x\n\n* balanced:\n    Driver: x\n"\n' \
        >"$BATS_TEST_TMPDIR/bin/powerprofilesctl"
    chmod +x "$BATS_TEST_TMPDIR/bin/powerprofilesctl"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run write
    [ "$status" -eq 0 ]
    [ "$(power_labels)" = "balanced performance " ]
}

@test "no power profiles: the power-mode row is dropped" {
    NUSKU_POWER_PROFILES="" run write
    [ "$status" -eq 0 ]
    ! jq -e '.widgets | index("buttons-grid#power")' "$OUT" >/dev/null
}

@test "re-running gives the same file" {
    export NUSKU_POWER_PROFILES="balanced performance"
    write
    cp "$OUT" "$BATS_TEST_TMPDIR/first"
    write
    cmp "$OUT" "$BATS_TEST_TMPDIR/first"
}

@test "a link in the way (an old Home Manager config.json) is replaced by a file" {
    mkdir -p "$(dirname "$OUT")"
    ln -s /nonexistent/config.json "$OUT"
    NUSKU_POWER_PROFILES="balanced" run write
    [ "$status" -eq 0 ]
    [ ! -L "$OUT" ]
    jq -e . "$OUT" >/dev/null
}

@test "an unreadable template fails without leaving a half-written file" {
    NUSKU_POWER_PROFILES="balanced" run scripts/nusku-swaync-config "$BATS_TEST_TMPDIR/nope.json" "$OUT"
    [ "$status" -ne 0 ]
    [ ! -e "$OUT" ]
    [ ! -e "$OUT.tmp" ]
}

@test "every toggle in the template is one nusku-quick knows" {
    run bash -c "jq -r '.. | .\"update-command\"? // empty' config/swaync/config.template.json | awk '{print \$NF}'"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    local t
    for t in $output; do
        grep -qE "^ +${t%%-*}[-*a-z]*\)" scripts/nusku-quick || { echo "unknown: $t"; false; }
    done
}

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

@test "nusku-quick: night light starts and stops hyprsunset" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : >"$CALLS"
    for c in hyprsunset pkill setsid; do
        printf '#!/bin/sh\necho "%s $*" >>"$CALLS"\n' "$c" >"$BATS_TEST_TMPDIR/bin/$c"
    done
    printf '#!/bin/sh\nexit "${PGREP_RC:-1}"\n' >"$BATS_TEST_TMPDIR/bin/pgrep"
    chmod +x "$BATS_TEST_TMPDIR/bin/"*
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick toggle night
    [ "$status" -eq 0 ]
    grep -qx 'setsid -f hyprsunset -t 4000' "$CALLS"
    PGREP_RC=0 PATH="$BATS_TEST_TMPDIR/bin:$PATH" run scripts/nusku-quick toggle night
    grep -qx 'pkill -x hyprsunset' "$CALLS"
}

@test "nusku-quick: usage without arguments" {
    run scripts/nusku-quick
    [ "$status" -eq 2 ]
    [[ "$output" == *"nusku-quick status NAME"* ]]
}
