-- Neovim's built-in plugin manager installs these on first start and pins
-- them in nvim-pack-lock.json. Update with :lua vim.pack.update().
vim.pack.add({
  "https://github.com/folke/snacks.nvim",
  "https://github.com/folke/which-key.nvim",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/echasnovski/mini.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/neovim/nvim-lspconfig",
}, { confirm = false })

-- File finder, search, file tree, terminal and buffer closing.
require("snacks").setup({
  explorer = { enabled = true },
  picker = {
    enabled = true,
    -- Dotfiles are useful here; still respect Git ignores and hide .git.
    sources = {
      files = { hidden = true, exclude = { ".git" } },
      grep = { hidden = true, exclude = { ".git" } },
      explorer = {
        hidden = true,
        exclude = { ".git" },
        layout = { preset = "sidebar", preview = false, layout = { position = "right" } },
        -- The tree sits on the right; Ctrl+H returns to the editor.
        win = { list = { keys = { ["<c-h>"] = function() vim.cmd.wincmd("h") end } } },
      },
    },
    icons = { files = { enabled = false } },
    win = { input = { keys = { ["<Esc>"] = { "close", mode = { "n", "i" } } } } },
  },
})
local map = vim.keymap.set
map("n", "<leader><space>", function() Snacks.picker.files() end, { desc = "Find file" })
map("n", "<leader>/", function() Snacks.picker.grep() end, { desc = "Search file contents" })
map("n", "<leader>,", function() Snacks.picker.buffers() end, { desc = "Open buffers" })
map("n", "<leader>e", function() Snacks.explorer() end, { desc = "File explorer" })
map("n", "<leader>sh", function() Snacks.picker.help() end, { desc = "Search help" })
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Close buffer" })
map("n", "<leader>bo", function() Snacks.bufdelete.other() end, { desc = "Close other buffers" })
-- Shared with Zed and VSCodium.
map({ "n", "t" }, "<C-M-S-j>", function() Snacks.terminal.toggle() end, { desc = "Toggle terminal" })

require("which-key").setup({
  icons = { mappings = false },
  spec = {
    { "<leader>b", group = "Buffer" },
    { "<leader>c", group = "Code" },
    { "<leader>s", group = "Search" },
    { "<leader>g", group = "Git" },
    { "<leader>gh", group = "Hunk" },
  },
})

require("gitsigns").setup({
  on_attach = function(buf)
    local gs = require("gitsigns")
    local function bmap(key, action, description)
      vim.keymap.set("n", key, action, { buffer = buf, desc = description })
    end
    -- A hunk is a consecutive group of changed lines. No staging/reset keys.
    bmap("]h", function() gs.nav_hunk("next") end, "Next Git hunk")
    bmap("[h", function() gs.nav_hunk("prev") end, "Previous Git hunk")
    bmap("<leader>ghp", gs.preview_hunk_inline, "Preview Git hunk")
  end,
})

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
