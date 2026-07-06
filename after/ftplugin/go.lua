vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("RetabOnSave", { clear = true }),
  callback = function()
    if vim.g.disable_autoformat or vim.b.disable_autoformat then return end
    vim.cmd('retab!')
  end
})
