-- Nusku: GDScript support when GDScript (Godot) was picked in the installer.
-- The language server is Godot's own (127.0.0.1:6005), running only while the Godot editor is open;
-- there is nothing to install for it. The gdscript, godot_resource and gdshader parsers come
-- with the other treesitter parsers from Nix (lua/plugins/nusku-nix.lua).
if not require("nusku.languages").has("gdscript") then
  return {}
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gdscript = { mason = false },
      },
    },
  },
}
