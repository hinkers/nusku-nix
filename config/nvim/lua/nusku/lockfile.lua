-- Nusku: where lazy.nvim keeps its lockfile.
-- lazy.nvim rewrites its lockfile with only the plugins in use, so the repo's lazy-lock.json
-- (Nusku's pins, covering every language's extras) would lose the other languages' plugins.
-- lazy.nvim therefore uses a writable copy in ~/.local/share/nvim, seeded from the repo's file.
-- On NixOS the repo's file is a link into the Nix store, and a copy keeps the store's read-only
-- mode, so the copy is made writable for lazy.nvim's updates.
--
-- The copy follows the repo's pins. A stamp next to it holds the sha256 of the repo file whose
-- pins the installed plugins are on. When a rebuild brings a lazy-lock.json with other content,
-- the copy is reseeded and lua/config/lazy.lua restores the plugins to it; the new stamp is
-- written only once that restore finished without errors. A failed restore (offline) leaves the
-- old stamp, so the next start reseeds and tries again. A rebuild that changes anything else
-- leaves the copy alone, so :Lazy update keeps writing the user's copy between new pins.
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

local function write(file, text)
  local f = io.open(file, "w")
  return f ~= nil and f:write(text) ~= nil and f:close() == true
end

---@return string? sha256 of the repo's lazy-lock.json
function M.hash()
  local text = read(M.repo)
  return text and vim.fn.sha256(text)
end

-- Record that the installed plugins are on the repo file's pins.
---@return boolean ok
function M.commit()
  local hash = M.hash()
  return hash ~= nil and write(M.stamp, hash)
end

---@param force? boolean overwrite an existing copy
---@return boolean ok
---@return "new"|"repo"|nil seeded why the copy was (re)made: there was none (lazy.nvim installs
---  from it, nothing to restore; stamped at once), or the repo's pins changed (restore, then
---  commit()); nil when the copy was left alone
function M.seed(force)
  local exists = vim.uv.fs_stat(M.path) ~= nil
  if not force and exists and read(M.stamp) == M.hash() then
    return true, nil
  end
  vim.fn.mkdir(vim.fn.fnamemodify(M.path, ":h"), "p")
  -- an older read-only copy can't be overwritten in place
  if exists then
    vim.uv.fs_unlink(M.path)
  end
  local ok = vim.uv.fs_copyfile(M.repo, M.path) == true and vim.uv.fs_chmod(M.path, tonumber("644", 8)) == true
  if not exists then
    return ok and M.commit(), "new"
  end
  return ok, "repo"
end

-- After a reseed because the repo's pins changed: put the installed plugins on them, and stamp
-- the copy only when every plugin got there.
function M.restore()
  vim.schedule(function()
    vim.notify("Nusku: the config's lazy-lock.json changed; restoring plugins to its revisions.", vim.log.levels.WARN)
    require("lazy.manage").restore({ show = false }):wait(function()
      local Plugin = require("lazy.core.plugin")
      local bad = {}
      for name, plugin in pairs(require("lazy.core.config").plugins) do
        if Plugin.has_errors(plugin) then
          bad[#bad + 1] = name
        end
      end
      table.sort(bad)
      local names = #bad > 5 and table.concat(vim.list_slice(bad, 1, 5), ", ") .. (", ... %d in all"):format(#bad)
        or table.concat(bad, ", ")
      if #bad == 0 and M.commit() then
        vim.notify("Nusku: plugins restored to the new pins. Restart Neovim to use them.", vim.log.levels.INFO)
      else
        vim.notify(
          "Nusku: the plugin restore did not finish ("
            .. (#bad > 0 and names or "could not write " .. M.stamp)
            .. "); it is tried again at the next start.",
          vim.log.levels.ERROR
        )
      end
    end)
  end)
end

return M
