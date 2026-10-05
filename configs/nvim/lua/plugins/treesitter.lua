return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- This plugin explicitly does not support lazy loading.
  config = function()
    -- Parser installation is explicit via :TSInstall; no compilers or CLIs
    -- are installed here. Missing parsers retain ordinary syntax highlighting.
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("dotfiles_treesitter", { clear = true }),
      callback = function(event)
        local lang = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
        if lang and vim.treesitter.language.add(lang) then
          vim.treesitter.start(event.buf, lang)
        end
      end,
    })
  end,
}
