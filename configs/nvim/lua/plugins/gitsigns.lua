return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    on_attach = function(buf)
      local gs = require("gitsigns")
      local function map(key, action, description)
        vim.keymap.set("n", key, action, { buffer = buf, desc = description })
      end
      -- A hunk is a consecutive group of changed lines. No staging/reset keys.
      map("]h", function() gs.nav_hunk("next") end, "Next Git hunk")
      map("[h", function() gs.nav_hunk("prev") end, "Previous Git hunk")
      map("<leader>ghp", gs.preview_hunk_inline, "Preview Git hunk")
    end,
  },
}
