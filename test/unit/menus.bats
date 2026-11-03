# nusku-menu-keybinds (the shell's keybind search lists and runs binds through it) and
# nusku-browser, with stub niri / notify-send / ... first on PATH. Ported from
# nusku-arch test/unit/menus.bats (nusku-browser had no tests there).

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    export NOTIFY_ARGS="$BATS_TEST_TMPDIR/notify-args"
    : >"$NOTIFY_ARGS"
    printf '#!/usr/bin/env bash\necho "$*" >>"$NOTIFY_ARGS"\n' >"$BATS_TEST_TMPDIR/bin/notify-send"
    chmod +x "$BATS_TEST_TMPDIR/bin/notify-send"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    : >"$CALLS"
}

# Stubs for niri and systemctl (the keybind search runs binds through `niri msg action`).
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

# The binds above in --list order: 0 Mod+Return, 1 Mod+Q, 2 Mod+Slash, 3 Mod+Ctrl+Left, 4 Mod+1,
# 5 Mod+2, 6 Mod+0, 7 Mod+Shift+1, 8 Mod+Shift+0, 9 Mod+WheelScrollDown, 10 XF86AudioMute,
# 11 Mod+Shift+E, then apps.kdl's 12 Super+Alt+E.

@test "keybinds --list: index, description, keys and runnable, in config order, with includes" {
    kb_setup
    run scripts/nusku-menu-keybinds --list
    [ "$status" -eq 0 ]
    [ "$(head -3 <<<"$output")" = "$(printf '0\tOpen terminal\tSuper + Enter\t1\n1\tClose window\tSuper + Q\t1\n2\tSearch keybinds\tSuper + /\t1')" ]
    grep -qxF "$(printf '3\tNarrower\tSuper + Ctrl + Left\t1')" <<<"$output"
    grep -qxF "$(printf '6\tFocus workspace 10\tSuper + 0\t1')" <<<"$output"
    grep -qxF "$(printf '9\tNext workspace\tSuper + Scroll down\t0')" <<<"$output"
    grep -qxF "$(printf '10\tMute\tMute key\t1')" <<<"$output"
    grep -qxF "$(printf '11\tQuit\tSuper + Shift + E\t1')" <<<"$output"
    grep -qxF "$(printf '12\tYazi "files"\tSuper + Alt + E\t1')" <<<"$output"
    [ "$(wc -l <<<"$output")" -eq 13 ]
    [ ! -s "$NIRI_ARGS" ]
}

@test "keybinds --run: the bind's action through niri msg action, with arguments and properties" {
    kb_setup
    for i in 0 3 6 10 11; do
        run scripts/nusku-menu-keybinds --run "$i"
        [ "$status" -eq 0 ]
    done
    [ "$(cat "$NIRI_ARGS")" = "$(printf '%s\n' 'msg action spawn -- kitty' \
        'msg action set-column-width -- -5%' \
        'msg action focus-workspace -- 10' \
        'msg action spawn-sh -- wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle' \
        'msg action quit --skip-confirmation')" ]
}

@test "keybinds --run: a mouse wheel bind, or one that isn't there, runs nothing" {
    kb_setup
    run scripts/nusku-menu-keybinds --run 9
    [ "$status" -eq 1 ]
    run scripts/nusku-menu-keybinds --run 99
    [ "$status" -eq 1 ]
    run scripts/nusku-menu-keybinds --run x
    [ "$status" -eq 1 ]
    [ ! -s "$NIRI_ARGS" ]
}

@test "keybinds: local.kdl replaces a key, and title=null hides it" {
    kb_setup
    cat >"$BATS_TEST_TMPDIR/cfg/nusku/local.kdl" <<'KDL'
binds {
    Mod+Return hotkey-overlay-title="My terminal" { spawn "foot"; }
    Mod+Q hotkey-overlay-title=null { close-window; }
    Mod+D { spawn "discord"; }
}
KDL
    run scripts/nusku-menu-keybinds --list
    [ "$(head -1 <<<"$output")" = "$(printf '0\tMy terminal\tSuper + Enter\t1')" ]
    ! grep -q 'Close window' <<<"$output" || false
    grep -qxF "$(printf '13\tRun discord\tSuper + D\t1')" <<<"$output"
    run scripts/nusku-menu-keybinds --run 1
    [ "$status" -eq 1 ]
    run scripts/nusku-menu-keybinds --run 0
    [ "$(cat "$NIRI_ARGS")" = 'msg action spawn -- foot' ]
}

@test "keybinds: no niri config, or no mode, is an error" {
    kb_setup
    run scripts/nusku-menu-keybinds
    [ "$status" -eq 2 ]
    export NUSKU_NIRI_CONFIG="$BATS_TEST_TMPDIR/nope/config.kdl"
    run scripts/nusku-menu-keybinds --list
    [ "$status" -eq 1 ]
    [[ "$output" == *"no niri config"* ]]
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
