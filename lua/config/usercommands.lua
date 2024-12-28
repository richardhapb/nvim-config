vim.api.nvim_create_user_command(
   'DiffOrig',
   function()
      vim.cmd('vert new')
      vim.cmd('setlocal buftype=nofile')
      vim.cmd('read #')
      vim.cmd('0delete _')
      vim.cmd('diffthis')
      vim.cmd('wincmd p')
      vim.cmd('diffthis')
   end,
   { desc = 'Compare current buffer with the original file' }
)

vim.api.nvim_create_user_command(
   'GPU',
   function()
      vim.cmd('G push -u')
   end,
   { desc = 'Git push to upstream' }
)


