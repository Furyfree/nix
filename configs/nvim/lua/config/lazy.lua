-- Basic editing still works if prerequisites or the initial download are missing.
if vim.fn.has("nvim-0.12") == 0 then
  vim.notify("Neovim 0.12+ is required for this plugin setup", vim.log.levels.WARN)
  return
end
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
local lock_ok, lock = pcall(function()
  local data = vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n"))
  assert(type(data["lazy.nvim"].commit) == "string" and data["lazy.nvim"].commit:match("^%x+$"))
  return data
end)
if not lock_ok then
  vim.notify("Neovim: missing or invalid lazy-lock.json; plugins not loaded", vim.log.levels.ERROR)
  return
end
if vim.fn.executable("git") == 0 then
  vim.notify("Neovim: install Git to verify and download plugins", vim.log.levels.WARN)
  return
end
if not vim.uv.fs_stat(lazypath) then
  -- Bootstrap the manager at the same revision as the tracked lockfile.
  local staging = lazypath .. ".bootstrap"
  local result = vim.system({
    "git", "clone", "--filter=blob:none", "--branch=main",
    "https://github.com/folke/lazy.nvim.git", staging,
  }, { text = true }):wait(60000)
  if result.code == 0 then
    result = vim.system({ "git", "-C", staging, "checkout", lock["lazy.nvim"].commit }, { text = true }):wait(60000)
  end
  if result.code ~= 0 then
    vim.notify("Neovim: lazy.nvim bootstrap failed: " .. (result.stderr or "unknown error"), vim.log.levels.ERROR)
    return
  end
  local renamed, err = vim.uv.fs_rename(staging, lazypath)
  if not renamed then
    vim.notify("Neovim: cannot finish lazy.nvim bootstrap: " .. err, vim.log.levels.ERROR)
    return
  end
end
-- Existing LazyVim installations may have a different manager at this path.
-- Never execute it or change its checkout implicitly when the lock disagrees.
local verified, revision = pcall(function()
  return vim.system({ "git", "-C", lazypath, "rev-parse", "HEAD" }, { text = true }):wait(5000)
end)
if not verified or revision.code ~= 0 or vim.trim(revision.stdout or "") ~= lock["lazy.nvim"].commit then
  vim.notify("Neovim: cannot verify lazy.nvim against lazy-lock.json; plugins not loaded. See README recovery",
    vim.log.levels.ERROR)
  return
end
vim.opt.rtp:prepend(lazypath)
local lazy_ok, lazy = pcall(require, "lazy")
if not lazy_ok then
  vim.notify("Neovim: incomplete lazy.nvim installation; see README recovery", vim.log.levels.ERROR)
  return
end

lazy.setup({
  require("plugins.snacks"),
  require("plugins.which-key"),
  require("plugins.gitsigns"),
  require("plugins.surround"),
  require("plugins.treesitter"),
}, {
  lockfile = lockfile,
  checker = { enabled = false }, -- Updates are explicit, not startup jobs.
  change_detection = { notify = false },
  rocks = { enabled = false },
  local_spec = false, -- Do not execute a project's .lazy.lua implicitly.
})
