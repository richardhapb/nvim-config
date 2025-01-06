
vim.api.nvim_create_user_command('MarpWatch', function()
   if vim.fn.executable('marp') == 0 then
      vim.notify('marp-cli is not installed, install it')
      return
   end

   if vim.fn.executable('tmux') == 0 then
      vim.notify('tmux is not installed, install it')
      return
   end

   local file_root = vim.fn.expand('%:p:r')

   local command = string.format(
      'tmux new-session -d -s marp "marp %s.md --watch --preview"',
      file_root
   )
   vim.fn.system(command)

   local buf = vim.api.nvim_get_current_buf()

   vim.api.nvim_create_autocmd('InsertLeave', {
      buffer = buf,
      callback = function()
         vim.cmd('silent! write')
      end
   })

   vim.api.nvim_create_autocmd('BufUnload', {
      buffer = buf,
      callback = function()
         vim.cmd('MarpStop')
      end
   })
end, {})

vim.api.nvim_create_user_command('MarpStop', function()
   if vim.fn.executable('tmux') == 0 or vim.fn.system('tmux has-session -t marp') == 0 then
      vim.notify('Nothing to stop')
      return
   end

   vim.fn.system('tmux kill-session -t marp')
end, {})

