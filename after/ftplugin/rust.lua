vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("RustAutoFmt", { clear = true }),
  callback = function()
    vim.lsp.buf.format()
  end
})

vim.cmd "set makeprg=cargo\\ test"
