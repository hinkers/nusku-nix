-- Nusku on NixOS: Neovim installs no software itself; Nix provides it (modules/home/neovim.nix).
--
-- Mason is off. Each picked language's servers, formatters and linters are on PATH (lib/langs.nix).
-- Without mason-lspconfig, LazyVim turns each configured server on with vim.lsp.enable, and
-- nvim-lspconfig's commands find the Nix binaries on PATH.
--
-- Treesitter: nixpkgs' nvim-treesitter, plus every grammar nixpkgs builds for that same
-- nvim-treesitter revision with its queries, as the parser directory. lazy.nvim doesn't clone
-- nvim-treesitter (a different revision's queries can break on these parsers), nothing is
-- installed or compiled at runtime (:TSUpdate / :TSInstall can't write to the Nix store), and
-- textobjects (queries on the same parsers) comes from the same nixpkgs.
--
-- blink.cmp: nixpkgs' blink.cmp, whose Rust fuzzy-matching library Nix builds into the plugin's
-- target/release. Cloned by lazy.nvim instead, blink.cmp downloads a prebuilt library from
-- GitHub; downloads stay off in any case (without the library it falls back to its Lua matcher).
local nix = require("nusku.nix")

local specs = {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  {
    "saghen/blink.cmp",
    dir = nix.blink,
    build = false,
    opts = { fuzzy = { prebuilt_binaries = { download = false } } },
  },
}

if nix.treesitter and nix.parsers then
  vim.list_extend(specs, {
    {
      "nvim-treesitter/nvim-treesitter",
      dir = nix.treesitter,
      build = false,
      -- LazyVim and the language extras extend ensure_installed; this runs after them.
      opts = function(_, opts)
        opts.install_dir = nix.parsers
        opts.ensure_installed = {}
      end,
    },
    { "nvim-treesitter/nvim-treesitter-textobjects", dir = nix.textobjects },
  })
end

-- Java: Mason's jdtls passed Lombok to the server; nixpkgs' jdtls doesn't, so add the jar.
if nix.lombok then
  specs[#specs + 1] = {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.cmd, "--jvm-arg=-javaagent:" .. nix.lombok)
    end,
  }
end

return specs
