return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    icons = { mappings = false },
    spec = {
      { "<leader>s", group = "Search" },
      { "<leader>g", group = "Git" },
      { "<leader>gh", group = "Hunk" },
    },
  },
}
