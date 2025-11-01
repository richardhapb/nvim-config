vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("RetabOnSave", { clear = true }),
  callback = function()
    vim.cmd('retab!')
  end
})
