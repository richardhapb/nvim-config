vim.opt_local.textwidth = 72
vim.opt_local.spell = true

local group = vim.api.nvim_create_augroup("GitCommitColorColumn", { clear = true })

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter" }, {
  group = group,
  buffer = 0,
  callback = function()
    if vim.fn.line(".") == 1 then
      vim.opt_local.colorcolumn = "50"
    else
      vim.opt_local.colorcolumn = "72"
    end
  end,
})
