-- Nusku: where lazy.nvim keeps its lockfile.
-- lazy.nvim rewrites its lockfile with only the plugins in use, so the repo's lazy-lock.json
-- (Nusku's pins, covering every language's extras) would lose the other languages' plugins and
-- leave the checkout dirty. lazy.nvim therefore uses a copy in ~/.local/share/nvim: seeded from
-- the repo's file when missing, and reset to it by the headless sync (nusku.sync).
-- On NixOS the repo's file is a read-only link into the Nix store, and a copy keeps that mode,
-- so the copy is made writable for lazy.nvim's updates.
-- To bump Nusku's pins, regenerate config/nvim/lazy-lock.json with every language enabled
-- (Mason and nvim-treesitter are not in it: Mason is off and treesitter comes from Nix).
local M = {}

M.repo = vim.fn.stdpath("config") .. "/lazy-lock.json"
M.path = vim.fn.stdpath("data") .. "/lazy-lock.json"

---@param force? boolean overwrite an existing copy
---@return boolean ok
function M.seed(force)
  if not force and vim.uv.fs_stat(M.path) then
    return true
  end
  vim.fn.mkdir(vim.fn.fnamemodify(M.path, ":h"), "p")
  -- an older read-only copy can't be overwritten in place
  if vim.uv.fs_stat(M.path) then
    vim.uv.fs_unlink(M.path)
  end
  return vim.uv.fs_copyfile(M.repo, M.path) == true and vim.uv.fs_chmod(M.path, tonumber("644", 8)) == true
end

return M
