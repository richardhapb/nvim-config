local function close_diff_buffers(main_buffer)
   local e, diff_buffers = pcall(vim.api.nvim_buf_get_var, main_buffer, 'diff_buffers')
   if e then
      for _, buffer in ipairs(diff_buffers) do
         if vim.api.nvim_buf_is_valid(buffer) then
            vim.api.nvim_buf_delete(buffer, { force = true })
         end
      end
   end
end

local M = {}

M.get_git_cwd = function()
   local git_cwd = vim.system({'git', 'rev-parse', '--show-toplevel'}):wait()

   if git_cwd.stderr ~= '' then
      vim.notify('Error: ' .. git_cwd.stderr, vim.log.levels.ERROR, { title = 'Git cwd' })
      return
   end

   return git_cwd.stdout:gsub('\n', '')
end

-- Get the text selected
M.get_visual_selection = function()
   vim.cmd('silent normal! "xy')
   return vim.fn.getreg('x')
end

M.diff_buffers = function(buffer1, buffer2, buffer1_name, buffer2_name)
   if buffer1 == nil or not vim.api.nvim_buf_is_valid(buffer1) then
      buffer1 = vim.api.nvim_get_current_buf()
   end
   if buffer1_name == nil then
      buffer1_name = vim.api.nvim_buf_get_name(buffer1)
      local file = vim.split(buffer1_name, '/')
      buffer1_name = file[#file]
   end

   if buffer2_name == nil then
      buffer2_name = 'diff:' .. buffer1_name
   end

   local prev_buffer2 = vim.fn.bufnr(buffer2_name)
   if prev_buffer2 ~= -1 then
      vim.api.nvim_buf_delete(prev_buffer2, { force = true })
   end

   vim.api.nvim_buf_set_name(buffer2, buffer2_name)

   local filetype1 = vim.api.nvim_get_option_value('filetype', { buf = buffer1 })

   vim.api.nvim_set_current_buf(buffer1)
   vim.cmd('diffthis')
   vim.cmd('vsplit')
   vim.api.nvim_set_current_buf(buffer2)
   vim.api.nvim_set_option_value('filetype', filetype1, { buf = buffer2 })
   vim.cmd('diffthis')
end

M.git_diff_name_only = function(branch_name)
   vim.cmd('G diff ' .. branch_name .. ' --name-only')
end

M.git_curr_line_diff_split = function(branch_name, main_buffer)
   if main_buffer == nil or not vim.api.nvim_buf_is_valid(main_buffer) then
      main_buffer = vim.api.nvim_get_current_buf()
   else
      vim.api.nvim_set_current_buf(main_buffer)
   end

   local current_line_text = vim.fn.getline('.')

   if current_line_text ~= nil then
      close_diff_buffers(main_buffer)

      local git_cwd = M.get_git_cwd()

      vim.cmd('new ' .. vim.fs.joinpath(git_cwd, current_line_text))
      local current_buffer = vim.api.nvim_get_current_buf()
      local filename = vim.api.nvim_buf_get_name(current_buffer)

      local file = vim.split(filename, '/')
      filename = file[#file]

      local branch_buffer = vim.api.nvim_create_buf(false, true)
      local branch_file_content = vim.system({ 'git', 'show', branch_name .. ':' .. current_line_text }, { text = true })
      :wait()

      if branch_file_content.stderr ~= '' then
         vim.notify('Error: ' .. branch_file_content.stderr, vim.log.levels.ERROR, { title = 'Git Diff' })
         return
      end

      vim.api.nvim_buf_set_lines(branch_buffer, 0, -1, false, vim.split(branch_file_content.stdout, '\n'))
      M.diff_buffers(current_buffer, branch_buffer, nil, branch_name .. ':' .. filename)

      vim.api.nvim_buf_set_var(main_buffer, 'diff_buffers', { current_buffer, branch_buffer })
   end
end

M.git_restore_curr_line = function(branch_name)
   local main_buffer = vim.api.nvim_get_current_buf()
   local current_line_text = vim.fn.getline('.')

   if current_line_text == nil then
      return
   end

   local cursor_line = vim.fn.line('.')
   M.buf_delete_line(main_buffer, cursor_line)

   local git_cwd = M.get_git_cwd()

   vim.system({
      'git',
      'restore',
      '--source',
      branch_name,
      '--staged',
      '--worktree',
      '--',
      vim.fs.joinpath(git_cwd, current_line_text) })
      :wait()

   close_diff_buffers(main_buffer)
   local success_message = 'Restored ' .. current_line_text .. ' from ' .. branch_name .. ' successfully!'
   vim.notify(success_message, vim.log.levels.INFO, { title = 'Git Restore' })
end

M.buf_delete_line = function(buffer, line)
   local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
   table.remove(lines, line)
   vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
end

--- @param lines table: list of strings to write in the buffer
--- @param split_type string: split type to open the buffer 'split'/'vsplit' (default: 'split')
--- @return integer: buffer number
M.buffer_log = function(lines, split_type)
   assert(type(lines) == 'table', 'lines must be a table')

   if split_type == nil then
      split_type = 'split'
   end

   local buffer = vim.api.nvim_create_buf(false, true)
   vim.cmd(split_type)
   vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
   vim.api.nvim_set_current_buf(buffer)
   vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buffer), 0 })

   local keys = { '<CR>', '<Esc>', 'q' }
   for _, key in ipairs(keys) do
      vim.keymap.set('n', key, '<Cmd>bd<CR>', { noremap = true, buffer = buffer })
   end

   return buffer
end

return M

