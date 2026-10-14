-- General keys, following LazyVim. Plugin and language keys live with their setup.
local map = vim.keymap.set

-- Open files: Shift+H/L like LazyVim; [b and ]b are built in.
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- Move between windows, such as the file tree and the editor.
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window below" })
map("n", "<C-k>", "<C-w>k", { desc = "Window above" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

map({ "n", "i", "x" }, "<C-s>", "<cmd>write<cr><esc>", { desc = "Save file" })
map({ "n", "i" }, "<esc>", "<cmd>nohlsearch<cr><esc>", { desc = "Clear search highlight" })

-- Keep the selection after indenting.
map("x", "<", "<gv")
map("x", ">", ">gv")

map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
