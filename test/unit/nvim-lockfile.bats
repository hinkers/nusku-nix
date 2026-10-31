# config/nvim/lua/nusku/lockfile.lua under `nvim -l`: lazy.nvim's writable lockfile copy, seeded
# from the config's lazy-lock.json (a read-only Nix store file) and reseeded when a rebuild
# brings a different one, while the user's own :Lazy update edits survive between rebuilds.

setup() {
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config" XDG_DATA_HOME="$BATS_TEST_TMPDIR/data"
    mkdir -p "$XDG_CONFIG_HOME/nvim"
    copy="$XDG_DATA_HOME/nvim/lazy-lock.json"
    cat >"$BATS_TEST_TMPDIR/seed.lua" <<'LUA'
package.path = "config/nvim/lua/?.lua;" .. package.path
local ok, why = require("nusku.lockfile").seed(arg[1] == "force")
io.stdout:write(tostring(ok) .. " " .. tostring(why) .. "\n")
LUA
}

teardown() { chmod -R u+w "$BATS_TEST_TMPDIR" 2>/dev/null || true; }

# store NAME CONTENT: a read-only "store" lazy-lock.json, linked as the config's.
store() {
    mkdir -p "$BATS_TEST_TMPDIR/store/$1"
    printf '%s\n' "$2" >"$BATS_TEST_TMPDIR/store/$1/lazy-lock.json"
    chmod 444 "$BATS_TEST_TMPDIR/store/$1/lazy-lock.json"
    ln -sfn "$BATS_TEST_TMPDIR/store/$1/lazy-lock.json" "$XDG_CONFIG_HOME/nvim/lazy-lock.json"
}

seed() { run nvim --headless -l "$BATS_TEST_TMPDIR/seed.lua" "$@"; }

@test "first start: a writable copy, stamped with the store file it came from" {
    store a '{ "pins": "a" }'
    seed
    [ "$output" = "true new" ]
    [ "$(cat "$copy")" = '{ "pins": "a" }' ]
    [ -w "$copy" ]
    [ "$(stat -c %a "$copy")" = 644 ]
    [ "$(cat "$copy.source")" = "$BATS_TEST_TMPDIR/store/a/lazy-lock.json" ]
}

@test "same config: the copy is left alone, including the user's :Lazy update" {
    store a '{ "pins": "a" }'
    seed
    echo '{ "pins": "updated by the user" }' >"$copy"
    seed
    [ "$output" = "true nil" ]
    [ "$(cat "$copy")" = '{ "pins": "updated by the user" }' ]
}

@test "a rebuild with new pins: the copy is replaced and reported for a restore" {
    store a '{ "pins": "a" }'
    seed
    echo '{ "pins": "updated by the user" }' >"$copy"
    store b '{ "pins": "b" }'
    seed
    [ "$output" = "true repo" ]
    [ "$(cat "$copy")" = '{ "pins": "b" }' ]
    [ -w "$copy" ]
    [ "$(cat "$copy.source")" = "$BATS_TEST_TMPDIR/store/b/lazy-lock.json" ]
}

@test "a copy without a stamp (made before stamps) is reseeded once" {
    store a '{ "pins": "a" }'
    mkdir -p "$(dirname "$copy")"
    echo '{ "pins": "old" }' >"$copy"
    chmod 444 "$copy"
    seed
    [ "$output" = "true repo" ]
    [ "$(cat "$copy")" = '{ "pins": "a" }' ]
    seed
    [ "$output" = "true nil" ]
}

@test "force (the headless sync) overwrites the user's copy" {
    store a '{ "pins": "a" }'
    seed
    echo '{ "pins": "updated by the user" }' >"$copy"
    seed force
    [ "$output" = "true repo" ]
    [ "$(cat "$copy")" = '{ "pins": "a" }' ]
}
