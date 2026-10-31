-- Nusku: headless first-time setup, for the installer and the VM test:
--   nvim --headless "+lua require('nusku.sync').run()"
-- Installs exactly the lazy-lock.json plugin revisions, so the first real launch has nothing
-- left to download. Language servers, formatters, linters and treesitter parsers come from Nix
-- (modules/home/neovim.nix), so there is nothing else to install.
-- Exits 0 when everything is in place; otherwise prints what failed and exits 1.
local M = {}

local function say(msg)
  io.stdout:write("\nnusku.sync: " .. msg .. "\n")
end

local function fail(msg)
  io.stderr:write("\nnusku.sync: FAILED: " .. msg .. "\n")
  vim.cmd.cquit(1)
end

local function plugins()
  -- Reset lazy.nvim's lockfile to the repo's pins and make lazy.nvim re-read it.
  if not require("nusku.lockfile").seed(true) then
    return "could not copy " .. require("nusku.lockfile").repo
  end
  require("lazy.manage.lock")._loaded = false
  require("lazy").restore({ wait = true, show = false })
  -- Every lazy-managed plugin installed without errors; the Nix-provided (local) ones present.
  local bad = require("nusku.lockfile").failed(true)
  if #bad > 0 then
    return "plugins not installed: " .. table.concat(bad, ", ")
  end
  local names = vim.tbl_keys(require("lazy.core.config").plugins)
  table.sort(names)
  require("lazy").load({ plugins = names })
  -- the installed plugins are on the repo's pins now (lua/nusku/lockfile.lua)
  if not require("nusku.lockfile").commit() then
    return "could not write " .. require("nusku.lockfile").stamp
  end
  say(("%d plugins at their lazy-lock.json revisions"):format(#names))
end

function M.run()
  local ok, err = pcall(plugins)
  if not ok or err then
    return fail(tostring(err))
  end
  say("done")
  vim.cmd("qa!")
end

return M
