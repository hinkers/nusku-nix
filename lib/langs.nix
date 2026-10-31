# What each picked language installs (ids from lib/catalogue.nix `langs`).
#
#   runtime  nusku-arch's packages/apps.list tokens: installed for every picked language, Neovim
#            or not (modules/nixos/langs.nix).
#   tools    what Mason installed on nusku-arch for that language's LazyVim extras
#            (config/nvim/lua/nusku/languages.lua): language servers, formatters and linters,
#            from nixpkgs instead. Installed only when Neovim is picked, as Mason only ran inside
#            Neovim (modules/home/neovim.nix).
#   core     tools LazyVim itself uses whatever the languages: lua_ls (servers), stylua and
#            shfmt (conform), Mason's own ensure_installed.
#
# Read from LazyVim 999700997f72227187d49d8b92667183dc7fc809 (nusku-arch's lazy-lock.json) and
# nvim-lspconfig 4b2b045b8ceb035f5c8bc9cab19b95706bfa6a19 for the commands. Debug adapters
# (codelldb, netcoredbg, delve, js-debug-adapter, java-debug-adapter) are left out: they only
# serve nvim-dap, which no picked extra turns on.
pkgs:
{
  core = with pkgs; [ lua-language-server stylua shfmt ];

  langs = with pkgs; {
    # lang.python with vim.g.lazyvim_python_lsp = "basedpyright": basedpyright + ruff (LSP, also
    # the formatter through LSP formatting).
    python = {
      runtime = [ python3 uv ];
      tools = [ basedpyright ruff ];
    };
    # lang.php: phpactor; phpcs (nvim-lint) and php-cs-fixer (conform) from Mason's list.
    php = {
      runtime = [ php phpPackages.composer ];
      tools = [ phpactor phpPackages.php-codesniffer phpPackages.php-cs-fixer ];
    };
    # No extra: the server is Godot's own (127.0.0.1:6005, while the editor is open).
    gdscript = {
      runtime = [ godot_4 ];
      tools = [ ];
    };
    # lang.typescript (vtsls) + lang.json (jsonls = vscode-json-language-server). Formatting
    # is the servers' own; LazyVim's prettier is a separate extra nusku-arch doesn't import.
    js = {
      runtime = [ nodejs ]; # npm comes with nodejs
      tools = [ vtsls vscode-langservers-extracted ];
    };
    # lang.rust: rustaceanvim runs rust-analyzer from PATH; rust-analyzer and rustfmt are rustup
    # components (rustup's proxies are in its package), added by modules/home/neovim.nix.
    rust = {
      runtime = [ rustup ];
      tools = [ ];
    };
    # lang.go: gopls; goimports + gofumpt (conform), golangci-lint (nvim-lint).
    go = {
      runtime = [ go ];
      tools = [ gopls gotools gofumpt golangci-lint ];
    };
    # lang.clangd (clangd from clang-tools) + lang.cmake: neocmakelsp, Mason's cmakelang
    # (cmake-format) and cmakelint (nvim-lint).
    cpp = {
      runtime = [ clang cmake ];
      tools = [ clang-tools neocmakelsp cmake-format cmake-lint ];
    };
    # lang.dotnet: omnisharp (nixpkgs names it OmniSharp, which nvim-lspconfig looks for first)
    # and fsautocomplete; csharpier and fantomas (conform). dotnet-sdk_10: Arch's dotnet-sdk is
    # the current release, nixpkgs' plain dotnet-sdk is 8.
    csharp = {
      runtime = [ dotnet-sdk_10 ];
      tools = [ omnisharp-roslyn fsautocomplete csharpier fantomas ];
    };
    # lang.java: nvim-jdtls runs jdtls from PATH. Mason's jdtls carried Lombok; nixpkgs' lombok
    # jar is passed to jdtls instead (modules/home/neovim.nix, lua/plugins/nusku-nix.lua).
    java = {
      runtime = [ jdk25 maven gradle ];
      tools = [ jdt-language-server ];
    };
    # No extra: LazyVim's core covers Lua (lua_ls, stylua: see core).
    lua = {
      runtime = [ lua lua.pkgs.luarocks ];
      tools = [ ];
    };
  };
}
