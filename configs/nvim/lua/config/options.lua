vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt
opt.number = true
opt.ignorecase = true
opt.smartcase = true -- Uppercase in a search makes it case-sensitive.
opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 4
opt.signcolumn = "yes"
opt.expandtab = true
opt.shiftwidth = 2 -- Filetype plugins and EditorConfig can override this.
opt.tabstop = 2
opt.wrap = false
opt.confirm = true -- Ask before abandoning unsaved changes.
opt.statusline = " %f %h%m%r%=%y  %l:%c "

-- Keep the system clipboard explicit: "+y / "+p, using native provider detection
-- (pbcopy on macOS, wl-copy/wl-paste or xclip on Linux). Deletes stay in Vim.
-- Undo contains earlier file contents; keep it private and outside the config.
local undo = vim.fn.stdpath("state") .. "/undo"
local undo_ok = pcall(function()
  vim.fn.mkdir(undo, "p", 448) -- 0700, including on first startup.
  assert(vim.fn.setfperm(undo, "rwx------") == 1)
end)
if undo_ok then
  opt.undodir = undo
  opt.undofile = true
else
  opt.undofile = false
  vim.notify("Neovim: cannot secure undo directory; persistent undo disabled", vim.log.levels.WARN)
end

-- Use the terminal's ANSI palette, including Noctalia colors in themed Ghostty.
-- No Noctalia files, hardcoded RGB palette, or generated theme watcher needed.
opt.termguicolors = false
vim.cmd.colorscheme("vim")
vim.api.nvim_set_hl(0, "NormalFloat", { link = "Normal" })
vim.api.nvim_set_hl(0, "SignColumn", { link = "Normal" })
