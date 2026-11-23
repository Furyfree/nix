-- Neovim's built-in plugin manager installs these on first start at the
-- versions in nvim-pack-lock.json. nupdate updates them and the lock file;
-- nswitch moves every machine to the lock file's versions.
-- Parsers follow nvim-treesitter's updates. Both update in a headless Neovim
-- that quits right after, so this waits for the parsers to build.
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(event)
    if event.data.spec.name ~= "nvim-treesitter" or event.data.kind ~= "update" then
      return
    end
    if not event.data.active then
      vim.cmd.packadd("nvim-treesitter")
    end
    require("nvim-treesitter").update():wait(300000)
  end,
})
vim.pack.add({
  "https://github.com/nvim-mini/mini.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/neovim/nvim-lspconfig",
}, { confirm = false })
-- Delete plugins dropped from the list above, as :help vim.pack shows, so
-- every machine's disk and the lock file follow this list.
local dropped = vim.iter(vim.pack.get(nil, { info = false }))
  :filter(function(plugin) return not plugin.active end)
  :map(function(plugin) return plugin.spec.name end)
  :totable()
if #dropped > 0 then
  vim.pack.del(dropped)
end

local map = vim.keymap.set

-- File finder and search. mini.pick leaves dotfiles to ripgrep's own config.
vim.env.RIPGREP_CONFIG_PATH = vim.fn.stdpath("config") .. "/ripgreprc"
require("mini.pick").setup()
map("n", "<leader><space>", "<cmd>Pick files<cr>", { desc = "Find file" })
map("n", "<leader>/", "<cmd>Pick grep_live<cr>", { desc = "Search file contents" })
map("n", "<leader>,", "<cmd>Pick buffers<cr>", { desc = "Open buffers" })
map("n", "<leader>sh", "<cmd>Pick help<cr>", { desc = "Search help" })

-- File tree from the working directory to the current file. Rename or delete
-- by editing the text, then = to apply.
require("mini.files").setup()
map("n", "<leader>e", function()
  local file = vim.api.nvim_buf_get_name(0)
  MiniFiles.open(vim.fn.filereadable(file) == 1 and file or nil)
  MiniFiles.reveal_cwd()
end, { desc = "File explorer" })

-- Close buffers but keep the window layout.
require("mini.bufremove").setup()
map("n", "<leader>bd", function() MiniBufremove.delete() end, { desc = "Close buffer" })
map("n", "<leader>bo", function()
  local current = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and buf ~= current then
      MiniBufremove.delete(buf)
    end
  end
end, { desc = "Close other buffers" })

-- Terminal at the bottom; the same key hides it and keeps the shell running.
-- Shared with Zed and VSCodium.
local terminal
map({ "n", "t" }, "<C-M-S-j>", function()
  local win = terminal and vim.fn.bufwinid(terminal) or -1
  if win ~= -1 then
    vim.api.nvim_win_hide(win)
    return
  end
  vim.cmd("botright split")
  if terminal and vim.api.nvim_buf_is_valid(terminal) then
    vim.api.nvim_win_set_buf(0, terminal)
  else
    vim.cmd.terminal()
    terminal = vim.api.nvim_get_current_buf()
  end
  vim.cmd.startinsert()
end, { desc = "Toggle terminal" })

-- Key hints, as in MiniMax: the keys below open a list of what can follow.
local clue = require("mini.clue")
clue.setup({
  clues = {
    { mode = "n", keys = "<leader>b", desc = "+Buffer" },
    { mode = "n", keys = "<leader>c", desc = "+Code" },
    { mode = "n", keys = "<leader>s", desc = "+Search" },
    { mode = "n", keys = "<leader>g", desc = "+Git" },
    { mode = "n", keys = "<leader>gh", desc = "+Hunk" },
    clue.gen_clues.builtin_completion(),
    clue.gen_clues.g(),
    clue.gen_clues.marks(),
    clue.gen_clues.registers(),
    clue.gen_clues.square_brackets(),
    clue.gen_clues.windows({ submode_resize = true }),
    clue.gen_clues.z(),
  },
  triggers = {
    { mode = { "n", "x" }, keys = "<leader>" },
    { mode = { "n", "x" }, keys = "[" },
    { mode = { "n", "x" }, keys = "]" },
    { mode = "i", keys = "<C-x>" },
    { mode = { "n", "x" }, keys = "g" },
    { mode = { "n", "x" }, keys = "'" },
    { mode = { "n", "x" }, keys = "`" },
    { mode = { "n", "x" }, keys = '"' },
    { mode = { "i", "c" }, keys = "<C-r>" },
    { mode = "n", keys = "<C-w>" },
    { mode = { "n", "x" }, keys = "z" },
  },
  window = { delay = 200 },
})

-- Git change marks; ]h and [h jump between hunks, consecutive changed lines.
-- No staging/reset keys.
require("mini.diff").setup({
  view = { style = "sign" },
  mappings = { apply = "", reset = "" },
})
map("n", "<leader>ghp", function() MiniDiff.toggle_overlay() end, { desc = "Show Git changes" })

-- Open files as tabs along the top.
require("mini.tabline").setup()
-- vim-surround keys: ysiw" adds quotes, cs"' changes them, ds" removes them.
require("mini.surround").setup({
  mappings = {
    add = "ys", delete = "ds", replace = "cs",
    find = "", find_left = "", highlight = "", update_n_lines = "",
    suffix_last = "", suffix_next = "",
  },
  search_method = "cover_or_next",
})
vim.keymap.del("x", "ys")
map("x", "S", [[:<C-u>lua MiniSurround.add('visual')<CR>]], { silent = true, desc = "Surround selection" })
map("n", "yss", "ys_", { remap = true, desc = "Surround line" })

-- Parsers compile on first start with tree-sitter and a C compiler.
-- Languages without one keep ordinary syntax highlighting.
require("nvim-treesitter").install({
  "bash", "c", "cpp", "diff", "go", "gomod", "json", "lua", "markdown",
  "markdown_inline", "nix", "python", "query", "rust", "toml", "typst",
  "vim", "vimdoc", "yaml",
})
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("config_treesitter", { clear = true }),
  callback = function(event)
    local lang = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
    if lang and vim.treesitter.language.add(lang) then
      vim.treesitter.start(event.buf, lang)
    end
  end,
})
