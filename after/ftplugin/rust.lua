vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("RustAutoFmt", { clear = true }),
  pattern = "*.rs",
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})

vim.cmd "compiler cargo"
vim.cmd "set makeprg=cargo\\ test"

vim.keymap.set("n", "M", function()
  vim.cmd("make check")
end)
