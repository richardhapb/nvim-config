vim.api.nvim_create_user_command('LatexBuild', function()
   vim.notify('Building ' .. vim.fn.expand('%:t') .. '...')
   local build_dir = vim.fn.expand('%:p:h') .. '/build'
   local file_path = vim.fn.expand('%:p')

   -- Verify if the build directory exists, if not, create it
   if vim.fn.isdirectory(build_dir) == 0 then
      vim.fn.mkdir(build_dir, 'p')
   end

   -- Verify if some .bib file exists in the same directory
   local biblio = vim.fn.glob(vim.fn.expand('%:p:h') .. '/*.bib')

   local command = string.format(
      'xelatex -output-directory=%s -interaction=nonstopmode -halt-on-error %s',
      build_dir,
      file_path
   )

   -- If a .bib file exists, run biber and rebuild the pdf
   if biblio ~= '' then
      command = command .. ' && biber ' .. build_dir .. '/' .. vim.fn.expand('%:t:r') .. ' && ' .. command
   end

   local results = vim.fn.system(command)
   local buffer = vim.api.nvim_create_buf(false, true)
   vim.cmd('split')
   vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.fn.split(results, '\n'))
   vim.api.nvim_set_current_buf(buffer)
   vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buffer), 0 })

   local keys = { '<CR>', '<Esc>', 'q' }
   for _, key in ipairs(keys) do
      vim.keymap.set('n', key, '<Cmd>bd<CR>', { noremap=true, buffer = buffer })
   end

   -- Open the pdf file after the build
   vim.api.nvim_create_autocmd('BufUnload', {
      buffer = buffer,
      callback = function()
         vim.fn.system('open ' .. build_dir .. '/' .. vim.fn.expand('%:t:r') .. '.pdf')
   end
   })

   vim.notify('Build complete')
end, {})

vim.api.nvim_create_user_command('LatexPreview', function()
   -- Verify if Texpresso command is available in vim (plugin)
   if vim.fn.exists(':TeXpresso') ~= 0 then
      vim.cmd('TeXpresso %')
      return
   end
   vim.notify('TeXpresso command not found. Install the plugin for live preview')

   if vim.fn.executable('texpresso') == 0 then
      vim.notify('texpresso is not installed, install it')
      return
   end

   if vim.fn.executable('tmux') == 0 then
      vim.notify('tmux is not installed, install it')
      return
   end

   vim.notify('Previewing ' .. vim.fn.expand('%:t') .. 'with texpresso (no live preview)')

   local tex_path = vim.fn.expand('%:p')
   local command = string.format(
      'tmux new-session -d -s texpresso "texpresso %s"',
      tex_path
   )
   vim.fn.system(command)
end, {})

vim.api.nvim_create_user_command('LatexShutdown', function()
   if vim.fn.exists(':TeXpresso') ~= 0 then
      vim.notify('Close TeXpresso with "q" in the preview window')
      return
   end

   if vim.fn.executable('tmux') == 0 or vim.fn.system('tmux has-session -t texpresso') == 0 then
      vim.notify('Nothing to shutdown')
      return
   end

   vim.fn.system('tmux kill-session -t texpresso')
end, {})

