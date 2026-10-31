# config/nvim/lua/nusku/lockfile.lua under `nvim -l`: lazy.nvim's writable lockfile copy, seeded
# from the config's lazy-lock.json (a read-only Nix store file). The stamp is the sha256 of the
# pins the installed plugins are on: new pins reseed the copy, and the stamp is written only
# after a restore without errors; any other rebuild keeps the user's :Lazy update edits.

setup() {
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config" XDG_DATA_HOME="$BATS_TEST_TMPDIR/data"
    mkdir -p "$XDG_CONFIG_HOME/nvim"
    copy="$XDG_DATA_HOME/nvim/lazy-lock.json"
    cat >"$BATS_TEST_TMPDIR/seed.lua" <<'LUA'
package.path = "config/nvim/lua/?.lua;" .. package.path
local L = require("nusku.lockfile")
if arg[1] == "commit" then
  io.stdout:write(tostring(L.commit()) .. "\n")
else
  local ok, why = L.seed(arg[1] == "force")
  io.stdout:write(tostring(ok) .. " " .. tostring(why) .. "\n")
end
LUA
    # restore() with lazy.nvim stubbed: arg[1] names the plugins whose restore task failed.
    # ts.nvim is a local plugin (a Nix store `dir`, as nvim-treesitter); arg[2] = "missing"
    # makes its directory missing.
    cat >"$BATS_TEST_TMPDIR/restore.lua" <<'LUA'
package.path = "config/nvim/lua/?.lua;" .. package.path
local failed = {}
for name in (arg[1] or ""):gmatch("[^,]+") do failed[name] = true end
package.loaded["lazy.core.config"] = { plugins = {
  ["a.nvim"] = { _ = { installed = true } },
  ["b.nvim"] = { _ = { installed = true } },
  ["ts.nvim"] = { _ = { is_local = true, installed = arg[2] ~= "missing" } },
} }
package.loaded["lazy.core.plugin"] = {
  has_errors = function(p) for name, q in pairs(package.loaded["lazy.core.config"].plugins) do
    if q == p then return failed[name] == true end end end,
}
package.loaded["lazy.manage"] = {
  restore = function(opts)
    io.stdout:write("restore show=" .. tostring(opts.show) .. "\n")
    return { wait = function(_, cb) vim.schedule(cb) end }
  end,
}
vim.notify = function(msg, level) io.stdout:write("notify " .. level .. ": " .. msg .. "\n") end
require("nusku.lockfile").restore()
vim.wait(200, function() return false end)
LUA
    # nusku.sync with lazy.nvim stubbed: a.nvim is lazy-managed, nvim-treesitter is local (a Nix
    # store `dir`). arg[1]: plugins whose tasks failed; arg[2]: plugins not installed / missing.
    cat >"$BATS_TEST_TMPDIR/sync.lua" <<'LUA'
package.path = "config/nvim/lua/?.lua;" .. package.path
local function set(s) local t = {} for n in (s or ""):gmatch("[^,]+") do t[n] = true end return t end
local failed, absent = set(arg[1]), set(arg[2])
package.loaded["lazy.core.config"] = { plugins = {
  ["a.nvim"] = { _ = { installed = not absent["a.nvim"] } },
  ["nvim-treesitter"] = { _ = { is_local = true, installed = not absent["nvim-treesitter"] } },
} }
package.loaded["lazy.core.plugin"] = {
  has_errors = function(p) for name, q in pairs(package.loaded["lazy.core.config"].plugins) do
    if q == p then return failed[name] == true end end end,
}
package.loaded["lazy.manage.lock"] = {}
package.loaded["lazy"] = { restore = function() end, load = function() end }
require("nusku.sync").run()
LUA
}

teardown() { chmod -R u+w "$BATS_TEST_TMPDIR" 2>/dev/null || true; }

# store NAME CONTENT: a read-only "store" copy of the config dir, linked as the config's
# lazy-lock.json (as Home Manager's recursive link does).
store() {
    mkdir -p "$BATS_TEST_TMPDIR/store/$1"
    printf '%s\n' "$2" >"$BATS_TEST_TMPDIR/store/$1/lazy-lock.json"
    chmod 444 "$BATS_TEST_TMPDIR/store/$1/lazy-lock.json"
    ln -sfn "$BATS_TEST_TMPDIR/store/$1/lazy-lock.json" "$XDG_CONFIG_HOME/nvim/lazy-lock.json"
}

sha() { printf '%s\n' "$1" | sha256sum | cut -d' ' -f1; }
seed() { run nvim --headless -l "$BATS_TEST_TMPDIR/seed.lua" "$@"; }
restore() { run nvim --headless -l "$BATS_TEST_TMPDIR/restore.lua" "$@"; }

@test "first start: a writable copy, stamped with the pins' sha256" {
    store a '{ "pins": "a" }'
    seed
    [ "$output" = "true new" ]
    [ "$(cat "$copy")" = '{ "pins": "a" }' ]
    [ "$(stat -c %a "$copy")" = 644 ]
    [ "$(cat "$copy.source")" = "$(sha '{ "pins": "a" }')" ]
}

@test "same config: the copy is left alone, including the user's :Lazy update" {
    store a '{ "pins": "a" }'
    seed
    echo '{ "pins": "updated by the user" }' >"$copy"
    seed
    [ "$output" = "true nil" ]
    [ "$(cat "$copy")" = '{ "pins": "updated by the user" }' ]
}

@test "a rebuild that changed other config files (same pins, new store path) keeps the user's copy" {
    store a '{ "pins": "a" }'
    seed
    echo '{ "pins": "updated by the user" }' >"$copy"
    store b '{ "pins": "a" }'
    seed
    [ "$output" = "true nil" ]
    [ "$(cat "$copy")" = '{ "pins": "updated by the user" }' ]
}

@test "new pins: the copy is replaced, the stamp waits for a good restore" {
    store a '{ "pins": "a" }'
    seed
    echo '{ "pins": "updated by the user" }' >"$copy"
    store b '{ "pins": "b" }'
    seed
    [ "$output" = "true repo" ]
    [ "$(cat "$copy")" = '{ "pins": "b" }' ]
    [ -w "$copy" ]
    [ "$(cat "$copy.source")" = "$(sha '{ "pins": "a" }')" ]
}

@test "restore never committed (offline): the next start reseeds and retries; commit ends it" {
    store a '{ "pins": "a" }'
    seed
    store b '{ "pins": "b" }'
    seed
    echo '{ "pins": "rewritten by lazy after a failed restore" }' >"$copy"
    seed
    [ "$output" = "true repo" ]
    [ "$(cat "$copy")" = '{ "pins": "b" }' ]
    run nvim --headless -l "$BATS_TEST_TMPDIR/seed.lua" commit
    [ "$output" = "true" ]
    [ "$(cat "$copy.source")" = "$(sha '{ "pins": "b" }')" ]
    seed
    [ "$output" = "true nil" ]
}

@test "a copy with an old-style or missing stamp is reseeded" {
    store a '{ "pins": "a" }'
    mkdir -p "$(dirname "$copy")"
    echo '{ "pins": "old" }' >"$copy"
    chmod 444 "$copy"
    echo "/nix/store/xxx-nvim/lazy-lock.json" >"$copy.source"
    seed
    [ "$output" = "true repo" ]
    [ "$(cat "$copy")" = '{ "pins": "a" }' ]
}

@test "force (the headless sync) overwrites the user's copy; sync commits after its own restore" {
    store a '{ "pins": "a" }'
    seed
    echo '{ "pins": "updated by the user" }' >"$copy"
    seed force
    [ "$output" = "true repo" ]
    [ "$(cat "$copy")" = '{ "pins": "a" }' ]
    grep -q 'require("nusku.lockfile").commit()' config/nvim/lua/nusku/sync.lua
}

@test "restore with a failed plugin: old stamp kept, one error naming it" {
    store a '{ "pins": "a" }'
    seed
    store b '{ "pins": "b" }'
    seed
    restore b.nvim
    [ "$status" -eq 0 ]
    [[ "$output" == *"restore show=false"* ]]
    [[ "$output" == *"notify 4: Nusku: the plugin restore did not finish (b.nvim); it is tried again at the next start."* ]]
    [ "$(grep -c "did not finish" <<<"$output")" -eq 1 ]
    [ "$(cat "$copy.source")" = "$(sha '{ "pins": "a" }')" ]
    seed
    [ "$output" = "true repo" ]
}

@test "restore without errors: the stamp moves to the new pins" {
    store a '{ "pins": "a" }'
    seed
    store b '{ "pins": "b" }'
    seed
    restore ""
    [[ "$output" == *"notify 2: Nusku: plugins restored to the new pins."* ]]
    [ "$(cat "$copy.source")" = "$(sha '{ "pins": "b" }')" ]
    seed
    [ "$output" = "true nil" ]
}

@test "restore: a Nix-provided (local) plugin whose tasks failed (helptags in the store) is not a failure" {
    store a '{ "pins": "a" }'
    seed
    store b '{ "pins": "b" }'
    seed
    restore ts.nvim
    [[ "$output" == *"notify 2: Nusku: plugins restored to the new pins."* ]]
    [ "$(cat "$copy.source")" = "$(sha '{ "pins": "b" }')" ]
    restore ts.nvim,b.nvim
    [[ "$output" == *"did not finish (b.nvim);"* ]]
}

@test "restore: a local plugin whose directory is missing is a failure" {
    store a '{ "pins": "a" }'
    seed
    store b '{ "pins": "b" }'
    seed
    restore "" missing
    [[ "$output" == *"did not finish (ts.nvim);"* ]]
    [ "$(cat "$copy.source")" = "$(sha '{ "pins": "a" }')" ]
}

@test "sync: Nix-provided (local) plugins are not reported missing; lazy-managed ones still are" {
    store a '{ "pins": "a" }'
    run nvim --headless -l "$BATS_TEST_TMPDIR/sync.lua" nvim-treesitter ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"nusku.sync: 2 plugins at their lazy-lock.json revisions"* ]]
    [[ "$output" != *FAILED* ]]
    run nvim --headless -l "$BATS_TEST_TMPDIR/sync.lua" "" a.nvim
    [ "$status" -eq 1 ]
    [[ "$output" == *"nusku.sync: FAILED: plugins not installed: a.nvim"* ]]
    run nvim --headless -l "$BATS_TEST_TMPDIR/sync.lua" a.nvim ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"plugins not installed: a.nvim"* ]]
    run nvim --headless -l "$BATS_TEST_TMPDIR/sync.lua" "" nvim-treesitter
    [ "$status" -eq 1 ]
    [[ "$output" == *"plugins not installed: nvim-treesitter"* ]]
}

@test "lazy.lua restores only with a UI (headless starts would race nusku.sync)" {
    grep -q 'if seeded == "repo" and #vim.api.nvim_list_uis() > 0 then' config/nvim/lua/config/lazy.lua
}
