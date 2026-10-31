-- Nusku: Nix store paths for this Neovim config, from ~/.config/nusku/nvim-nix.lua (written by
-- modules/home/neovim.nix):
--   treesitter   nixpkgs' nvim-treesitter (main branch)
--   textobjects  nixpkgs' nvim-treesitter-textobjects
--   parsers      every nixpkgs grammar (parser/*.so) with its queries, built for that nvim-treesitter
--   blink        nixpkgs' blink.cmp, with its fuzzy-matching library (target/release) built by Nix
--   lombok       Lombok's jar for jdtls (only when Java is picked)
local file = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")) .. "/nusku/nvim-nix.lua"

local ok, paths = pcall(dofile, file)
if not ok or type(paths) ~= "table" then
  vim.schedule(function()
    vim.notify(
      "Nusku: " .. file .. " is missing or broken, so nvim-treesitter is cloned by lazy.nvim and its "
        .. "parsers compiled at runtime. Rebuild (Home Manager writes it) to use the ones from Nix.",
      vim.log.levels.WARN
    )
  end)
  return {}
end
return paths
