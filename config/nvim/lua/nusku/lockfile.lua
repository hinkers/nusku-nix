-- Nusku: where lazy.nvim keeps its lockfile.
-- lazy.nvim rewrites its lockfile with only the plugins in use, so the repo's lazy-lock.json
-- (Nusku's pins, covering every language's extras) would lose the other languages' plugins.
-- lazy.nvim therefore uses a writable copy in ~/.local/share/nvim, seeded from the repo's file.
-- On NixOS the repo's file is a link into the Nix store, and a copy keeps the store's read-only
-- mode, so the copy is made writable for lazy.nvim's updates.
--
-- The copy follows the repo: it is stamped with the store path of the file it came from. When
-- a rebuild brings a different lazy-lock.json (new store path), the copy is reseeded and
-- lua/config/lazy.lua restores the plugins to the new pins, once. Between rebuilds the stamp
-- stays the same, so :Lazy update keeps writing the user's copy.
-- To bump Nusku's pins, regenerate config/nvim/lazy-lock.json with every language enabled
-- (Mason and nvim-treesitter are not in it: Mason is off and treesitter comes from Nix).
local M = {}

M.repo = vim.fn.stdpath("config") .. "/lazy-lock.json"
M.path = vim.fn.stdpath("data") .. "/lazy-lock.json"
M.stamp = M.path .. ".source"

local function read(file)
  local f = io.open(file, "r")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

---@param force? boolean overwrite an existing copy
---@return boolean ok
---@return "new"|"repo"|nil seeded why the copy was (re)made: no copy yet, or the repo's file changed
function M.seed(force)
  local source = vim.uv.fs_realpath(M.repo) or M.repo
  local exists = vim.uv.fs_stat(M.path) ~= nil
  if not force and exists and read(M.stamp) == source then
    return true, nil
  end
  vim.fn.mkdir(vim.fn.fnamemodify(M.path, ":h"), "p")
  -- an older read-only copy can't be overwritten in place
  if exists then
    vim.uv.fs_unlink(M.path)
  end
  local ok = vim.uv.fs_copyfile(M.repo, M.path) == true and vim.uv.fs_chmod(M.path, tonumber("644", 8)) == true
  if ok then
    local f = io.open(M.stamp, "w")
    ok = f ~= nil and f:write(source) ~= nil and f:close() == true
  end
  return ok, exists and "repo" or "new"
end

-- After a reseed because the repo's pins changed: put the installed plugins on them.
function M.restore()
  vim.schedule(function()
    vim.notify(
      "Nusku: the config's lazy-lock.json changed; restoring plugins to its revisions. Restart Neovim when it finishes.",
      vim.log.levels.WARN
    )
    require("lazy").restore({ show = false })
  end)
end

return M
