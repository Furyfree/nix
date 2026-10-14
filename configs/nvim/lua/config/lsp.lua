-- Language servers come from Mise or Nix; nvim-lspconfig only defines them.
-- Built-in keys: grn rename, grr references, gra code action, gri
-- implementation, K documentation, gO outline, ]d/[d next/previous diagnostic.
vim.lsp.config("lua_ls", {
  settings = { Lua = { workspace = { library = { vim.env.VIMRUNTIME } } } },
})
vim.lsp.enable({
  "bashls", "clangd", "gopls", "lua_ls", "nixd", "ruff",
  "rust_analyzer", "taplo", "tinymist", "ty",
})

vim.diagnostic.config({ virtual_text = true })
-- Complete as you type; the first item is selected so Enter accepts it.
vim.opt.completeopt = { "menuone", "noinsert", "popup", "fuzzy" }

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("config_lsp", { clear = true }),
  callback = function(event)
    local client = assert(vim.lsp.get_client_by_id(event.data.client_id))
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
    end
    local function map(key, action, description)
      vim.keymap.set("n", key, action, { buffer = event.buf, desc = description })
    end
    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("<leader>cf", vim.lsp.buf.format, "Format file")
  end,
})
