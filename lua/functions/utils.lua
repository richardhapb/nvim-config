local function close_diff_buffers(main_buffer)
   local e, diff_buffers = pcall(vim.api.nvim_buf_get_var, main_buffer, 'diff_buffers')
   if e then
      for _, buffer in ipairs(diff_buffers) do
         if vim.api.nvim_buf_is_valid(buffer) then
            vim.api.nvim_buf_delete(buffer, {force = true})
         end
      end
   end
end

local M = {}

-- Separate by delim
M.split = function(str, delim)
    local result = {}
    for match in (str .. delim):gmatch("(.-)" .. delim) do
        table.insert(result, match)
    end
    return result
end

-- Get the text selected
M.get_visual_selection = function()
    local mode = vim.api.nvim_get_mode().mode

    local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, "<"))
    local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, ">"))

    if not start_row or not start_col or not end_row or not end_col then
        print("No valid selection")
        return ""
    end

    end_col = end_col + 1

    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

    if mode == "v" then
        if #lines == 1 then -- One line
            lines[1] = string.sub(lines[1], start_col + 1, end_col)
        else -- Many lines
            lines[1] = string.sub(lines[1], start_col + 1)
            lines[#lines] = string.sub(lines[#lines], 1, end_col)
        end
    elseif mode == "\22" then -- <C-v> - Block visual mode
        for i = 1, #lines do
            lines[i] = string.sub(lines[i], start_col + 1, end_col + 1)
        end
    end
    return table.concat(lines, "\n")
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
      vim.api.nvim_buf_delete(prev_buffer2, {force = true})
   end

   vim.api.nvim_buf_set_name(buffer2, buffer2_name)

   local filetype1 = vim.api.nvim_get_option_value('filetype', {buf = buffer1})

   vim.api.nvim_set_current_buf(buffer1)
   vim.cmd('diffthis')
   vim.cmd('vsplit')
   vim.api.nvim_set_current_buf(buffer2)
   vim.api.nvim_set_option_value('filetype', filetype1, {buf = buffer2})
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

   local current_cursor_line = vim.fn.line('.')
   local current_line_text = vim.api.nvim_buf_get_lines(main_buffer, current_cursor_line - 1, current_cursor_line, false)[1]

   if current_line_text ~= nil then
      close_diff_buffers(main_buffer)

      vim.cmd('new ' .. current_line_text)
      local current_buffer = vim.api.nvim_get_current_buf()
      local filename = vim.api.nvim_buf_get_name(current_buffer)

      local file = vim.split(filename, '/')
      filename = file[#file]

      local branch_buffer = vim.api.nvim_create_buf(false, true)
      local branch_file_content = vim.fn.system('git show ' .. branch_name .. ':' .. current_line_text)

      vim.api.nvim_buf_set_lines(branch_buffer, 0, -1, false, vim.split(branch_file_content, '\n'))
      M.diff_buffers(current_buffer, branch_buffer, nil, branch_name .. ':' .. filename)

      vim.api.nvim_buf_set_var(main_buffer, 'diff_buffers', {current_buffer, branch_buffer})
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

   vim.fn.system('git restore --source ' .. branch_name .. ' --staged --worktree -- ' .. current_line_text)

   close_diff_buffers(main_buffer)
   local success_message = 'Restored ' .. current_line_text .. ' from ' .. branch_name .. ' successfully!'
   vim.notify(success_message, vim.log.levels.INFO, {title = 'Git Restore'})
end

M.buf_delete_line = function(buffer, line)
   local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
   table.remove(lines, line)
   vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
end

M.close_all_buffers_but_current = function(force)
   if force == nil then
      force = false
   end
   local current_bufnr = vim.fn.bufnr('%')
   local buflist = vim.api.nvim_list_bufs()
   for _, buf in ipairs(buflist) do
      if buf ~= current_bufnr then
         vim.api.nvim_buf_delete(buf, {force = force})
      end
   end
end

return M

