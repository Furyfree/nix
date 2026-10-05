return {
  "folke/snacks.nvim",
  lazy = false,
  priority = 1000,
  opts = {
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
        },
      },
      icons = { files = { enabled = false } },
      win = { input = { keys = { ["<Esc>"] = { "close", mode = { "n", "i" } } } } },
    },
  },
  keys = {
    { "<leader><space>", function() Snacks.picker.files() end, desc = "Find file" },
    { "<leader>/", function() Snacks.picker.grep() end, desc = "Search file contents" },
    { "<leader>,", function() Snacks.picker.buffers() end, desc = "Open buffers" },
    { "<leader>e", function() Snacks.explorer() end, desc = "File explorer" },
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Search help" },
  },
}
