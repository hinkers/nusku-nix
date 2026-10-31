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

# blink_spec: the saghen/blink.cmp spec lua/plugins/nusku-nix.lua returns, one line.
blink_spec() {
    run nvim --headless -u NONE \
        "+lua package.path = 'config/nvim/lua/?.lua;' .. package.path
         local found = 'none'
         for _, s in ipairs(dofile('config/nvim/lua/plugins/nusku-nix.lua')) do
           if s[1] == 'saghen/blink.cmp' then
             local opts = type(s.opts) == 'function' and s.opts(nil, {}) or s.opts
             found = ('dir=%s build=%s download=%s'):format(tostring(s.dir), tostring(s.build),
               tostring(vim.tbl_get(opts or {}, 'fuzzy', 'prebuilt_binaries', 'download')))
           end
         end
         io.stdout:write('blink ' .. found .. '\n')" +qa
}

@test "blink.cmp comes from the Nix store (its fuzzy library built by nixpkgs) and never downloads one" {
    echo 'return { blink = "/nix/store/x-vimplugin-blink.cmp-1.10.2" }' >"$XDG_CONFIG_HOME/nusku/nvim-nix.lua"
    blink_spec
    [[ "$output" == *"blink dir=/nix/store/x-vimplugin-blink.cmp-1.10.2 build=false download=false"* ]]
}

@test "blink.cmp without a Nix path (nvim-nix.lua missing): still never downloads a binary" {
    blink_spec
    [[ "$output" == *"blink dir=nil build=false download=false"* ]]
}
