# nusku-obsidian-theme: Catppuccin in every Obsidian vault, without replacing a theme the user
# picked (modules/home/browsers.nix runs it on each rebuild and each login).

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME/obsidian"
    # A stand-in for the theme in the Nix store: read-only, like the store.
    export NUSKU_OBSIDIAN_THEME="$BATS_TEST_TMPDIR/theme"
    mkdir -p "$NUSKU_OBSIDIAN_THEME"
    echo '{ "name": "Catppuccin", "version": "1" }' >"$NUSKU_OBSIDIAN_THEME/manifest.json"
    echo '/* v1 */' >"$NUSKU_OBSIDIAN_THEME/theme.css"
    chmod -R a-w "$NUSKU_OBSIDIAN_THEME"
}

teardown() { chmod -R u+w "$BATS_TEST_TMPDIR" 2>/dev/null || true; }

# vaults PATH...: Obsidian's vault list with these paths.
vaults() {
    local p json='{}'
    for p in "$@"; do
        json=$(jq --arg p "$p" '.vaults[($p | @base64)] = { path: $p, ts: 1 }' <<<"$json")
    done
    printf '%s\n' "$json" >"$XDG_CONFIG_HOME/obsidian/obsidian.json"
}

vault() { mkdir -p "$HOME/$1/.obsidian" && printf '%s\n' "$HOME/$1"; }

theme() { scripts/nusku-obsidian-theme; }

@test "a vault without appearance.json gets the theme, selected" {
    v=$(vault Notes)
    vaults "$v"
    run theme
    [ "$status" -eq 0 ]
    [ "$(jq -r .cssTheme "$v/.obsidian/appearance.json")" = Catppuccin ]
    [ "$(cat "$v/.obsidian/themes/Catppuccin/theme.css")" = '/* v1 */' ]
    [ -w "$v/.obsidian/themes/Catppuccin/theme.css" ]
    [ -w "$v/.obsidian/themes/Catppuccin" ]
}

@test "a vault Obsidian hasn't opened yet (no .obsidian) is themed too" {
    mkdir -p "$HOME/New"
    vaults "$HOME/New"
    run theme
    [ "$status" -eq 0 ]
    [ "$(jq -r .cssTheme "$HOME/New/.obsidian/appearance.json")" = Catppuccin ]
}

@test "the user's own theme stays selected; other keys are kept" {
    v=$(vault Notes)
    echo '{ "cssTheme": "Minimal", "baseFontSize": 18, "theme": "obsidian" }' >"$v/.obsidian/appearance.json"
    vaults "$v"
    run theme
    [ "$status" -eq 0 ]
    [ "$(jq -c . "$v/.obsidian/appearance.json")" = '{"cssTheme":"Minimal","baseFontSize":18,"theme":"obsidian"}' ]
    # The theme is still there to pick.
    [ -f "$v/.obsidian/themes/Catppuccin/theme.css" ]
}

@test "first run on an empty cssTheme selects Catppuccin (other keys kept), and marks the vault" {
    v=$(vault Notes)
    echo '{ "cssTheme": "", "accentColor": "#ff0000" }' >"$v/.obsidian/appearance.json"
    vaults "$v"
    run theme
    [ "$status" -eq 0 ]
    [ "$(jq -c . "$v/.obsidian/appearance.json")" = '{"cssTheme":"Catppuccin","accentColor":"#ff0000"}' ]
    [ -e "$v/.obsidian/.nusku-theme-applied" ]
}

@test "the user then picks Obsidian's Default theme: it sticks on later runs" {
    v=$(vault Notes)
    vaults "$v"
    theme
    [ "$(jq -r .cssTheme "$v/.obsidian/appearance.json")" = Catppuccin ]
    # What Obsidian writes for its built-in Default theme.
    echo '{ "cssTheme": "" }' >"$v/.obsidian/appearance.json"
    run theme
    [ "$status" -eq 0 ]
    [ "$(jq -c . "$v/.obsidian/appearance.json")" = '{"cssTheme":""}' ]
    # The theme files are still refreshed, for picking it again.
    [ -f "$v/.obsidian/themes/Catppuccin/theme.css" ]
}

@test "a user theme left alone on the first run marks the vault: later runs leave it, even at Default" {
    v=$(vault Notes)
    echo '{ "cssTheme": "Minimal" }' >"$v/.obsidian/appearance.json"
    vaults "$v"
    theme
    [ -e "$v/.obsidian/.nusku-theme-applied" ]
    [ "$(jq -r .cssTheme "$v/.obsidian/appearance.json")" = Minimal ]
    echo '{ "cssTheme": "" }' >"$v/.obsidian/appearance.json"
    run theme
    [ "$status" -eq 0 ]
    [ "$(jq -c . "$v/.obsidian/appearance.json")" = '{"cssTheme":""}' ]
}

@test "the theme files are refreshed on each run" {
    v=$(vault Notes)
    vaults "$v"
    theme
    echo 'stale' >"$v/.obsidian/themes/Catppuccin/extra.css"
    chmod u+w "$NUSKU_OBSIDIAN_THEME" "$NUSKU_OBSIDIAN_THEME/theme.css"
    echo '/* v2 */' >"$NUSKU_OBSIDIAN_THEME/theme.css"
    run theme
    [ "$status" -eq 0 ]
    [ "$(cat "$v/.obsidian/themes/Catppuccin/theme.css")" = '/* v2 */' ]
    [ ! -e "$v/.obsidian/themes/Catppuccin/extra.css" ]
    # No leftovers from the swap.
    [ "$(ls -A "$v/.obsidian/themes")" = Catppuccin ]
    [ "$(ls -A "$v/.obsidian" | tr '\n' ' ')" = ".nusku-theme-applied appearance.json themes " ]
}

@test "no obsidian.json (Obsidian never started): exit 0, nothing written" {
    rm -rf "$XDG_CONFIG_HOME/obsidian"
    run theme
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a vault path that no longer exists is skipped quietly" {
    v=$(vault Notes)
    vaults "$HOME/Gone" "$v"
    run theme
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$HOME/Gone" ]
    [ "$(jq -r .cssTheme "$v/.obsidian/appearance.json")" = Catppuccin ]
}

@test "bad JSON in one vault: that vault is left as it was, the others are themed" {
    bad=$(vault Bad)
    good=$(vault Good)
    printf '{ "cssTheme": ' >"$bad/.obsidian/appearance.json"
    vaults "$bad" "$good"
    run theme
    [ "$status" -eq 1 ]
    [[ "$output" == *"$bad"* ]]
    [ "$(cat "$bad/.obsidian/appearance.json")" = '{ "cssTheme": ' ]
    [ "$(ls -A "$bad/.obsidian")" = appearance.json ]
    [ "$(jq -r .cssTheme "$good/.obsidian/appearance.json")" = Catppuccin ]
}

@test "paths with spaces work" {
    v=$(vault "My Notes")
    vaults "$v"
    run theme
    [ "$status" -eq 0 ]
    [ "$(jq -r .cssTheme "$v/.obsidian/appearance.json")" = Catppuccin ]
}
