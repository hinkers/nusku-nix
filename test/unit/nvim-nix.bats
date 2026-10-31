# config/nvim/lua/nusku/nix.lua: the Nix store paths Home Manager writes to
# ~/.config/nusku/nvim-nix.lua; a missing file is reported instead of silently falling back to
# lazy.nvim's nvim-treesitter with parsers compiled at runtime.

setup() {
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    mkdir -p "$XDG_CONFIG_HOME/nusku"
}

load_nix() {
    run nvim --headless -u NONE \
        "+lua package.path = 'config/nvim/lua/?.lua;' .. package.path
         local p = require('nusku.nix'); vim.wait(50)
         io.stdout:write('paths=' .. vim.inspect(p, { newline = '' }) .. '\n')" +qa
}

@test "nvim-nix.lua present: its paths, no warning" {
    echo 'return { parsers = "/nix/store/x-grammars" }' >"$XDG_CONFIG_HOME/nusku/nvim-nix.lua"
    load_nix
    [[ "$output" == *'paths={  parsers = "/nix/store/x-grammars"}'* ]]
    [[ "$output" != *"missing"* ]]
}

@test "nvim-nix.lua missing: empty paths and a warning naming the file" {
    load_nix
    [[ "$output" == *"paths={}"* ]]
    [[ "$output" == *"$XDG_CONFIG_HOME/nusku/nvim-nix.lua is missing"* ]]
}
