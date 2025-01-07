local function sync_buffers(buf1, buf2)
   if not vim.api.nvim_buf_is_valid(buf1) or not vim.api.nvim_buf_is_valid(buf2) then
      print("Invalid buffers.")
      return
   end

   local function copy_content(from_buf, to_buf)
      local lines = vim.api.nvim_buf_get_lines(from_buf, 0, -1, false)

      table.remove(lines, 1)
      table.remove(lines, #lines)

      vim.api.nvim_buf_set_lines(to_buf, 0, -1, false, lines)
   end

   vim.api.nvim_create_autocmd("TextChanged", {
      buffer = buf1,
      callback = function() copy_content(buf1, buf2) end,
   })
   vim.api.nvim_create_autocmd("TextChangedI", {
      buffer = buf1,
      callback = function() copy_content(buf1, buf2) end,
   })
end

local function check_or_create_dir(path)
   if vim.fn.isdirectory(path) == 0 then
      vim.fn.mkdir(path, 'p')
   end
end


local function new_mermaid()
   local name = vim.fn.input('Diagram name: ')

   if name == '' then
      return
   end

   local current_buffer = vim.api.nvim_get_current_buf()

   local function open_win(buffer, opts)
      if not vim.api.nvim_buf_is_valid(buffer) or opts == nil then
         return
      end

      return vim.api.nvim_open_win(buffer, true, opts)
   end

   local function open_windows(buffer1, buffer2)
      local opts = {
         relative = 'editor',
         width = 100,
         height = 30,
         row = 5,
         col = 30,
         style = 'minimal',
         border = 'single',
      }

      if not vim.api.nvim_buf_is_valid(buffer1) or not vim.api.nvim_buf_is_valid(buffer2) then
         return
      end

      local win2 = open_win(buffer2, opts)
      local win1 = open_win(buffer1, opts)

      if win1 == nil or win2 == nil then
         return
      end

      local lines = vim.api.nvim_buf_get_lines(buffer2, 0, -1, false)

      if #lines == 0 then
         vim.api.nvim_buf_set_lines(buffer1, 0, -1, false, {
            '```mermaid',
            '',
            '```',
         })
      else
         table.insert(lines, 1, '```mermaid')
         table.insert(lines, '```')

         vim.api.nvim_buf_set_lines(buffer1, 0, -1, false, lines)
      end

      vim.api.nvim_create_autocmd("WinClosed", {
         pattern = tostring(win1),
         callback = function()
            if vim.api.nvim_win_is_valid(win2) then
               vim.api.nvim_win_close(win2, true)
            end
            if vim.api.nvim_buf_is_valid(buffer2) then
               vim.api.nvim_buf_delete(buffer2, { force = true })
            end
         end,
      })


      return win1, win2
   end


   local diag_path = vim.fs.joinpath(vim.fn.expand('%:p:h'), 'diagrams')



   check_or_create_dir(diag_path)

   local path = string.format('%s/%s.mmd', diag_path, name)
   local prev_buf = vim.fn.bufnr(path)
   local win, md_win

   local md_buffer = vim.api.nvim_create_buf(true, true)
   vim.api.nvim_set_option_value('filetype', 'markdown', { buf = md_buffer })

   if prev_buf ~= -1 then
      md_win, win = open_windows(md_buffer, prev_buf)
      return
   end

   local lines

   if vim.fn.filereadable(path) == 1 then
       lines = vim.fn.readfile(path)
   end

   local buffer = vim.api.nvim_create_buf(false, false)
   vim.api.nvim_set_option_value('filetype', 'mermaid', { buf = buffer })
   vim.api.nvim_buf_set_name(buffer, path)
   sync_buffers(md_buffer, buffer)

   if lines then
      vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
   end

   if win == nil then
      md_win, win = open_windows(md_buffer, buffer)
   end

   local function execute_fun_on_mmd_win(f)
      if win == nil or md_win == nil then
         return
      end

      vim.api.nvim_set_current_win(win)
      f()
      vim.api.nvim_set_current_win(md_win)
   end

   local function compile_diagram(theme, transparent)
      if not vim.api.nvim_buf_is_valid(buffer) then
         return
      end

      local opt_transparent = transparent and '-b transparent' or ''

      execute_fun_on_mmd_win(function() vim.cmd('w!') end)
      local command = string.format('mmdc -i %s -o %s.svg -t %s %s', path, diag_path .. '/' .. name, theme, opt_transparent)

      local result = vim.fn.system(command)

      vim.notify(result)
   end

   local map = vim.keymap.set

   map('n', '<leader>M', '<cmd>MarkdownPreview<CR>', { buffer = md_buffer })
   map('n', '<leader>q', '<cmd>q<CR>', { buffer = md_buffer })
   map('n', '<leader>w', function() execute_fun_on_mmd_win(function() vim.cmd('w!') end) end, { buffer = md_buffer })
   map('n', '<leader>cl', function() execute_fun_on_mmd_win(function() compile_diagram('neutral') end) end,
      { buffer = md_buffer })
   map('n', '<leader>cd', function() execute_fun_on_mmd_win(function() compile_diagram('dark') end) end,
      { buffer = md_buffer })
   map('n', '<leader>tl', function() execute_fun_on_mmd_win(function() compile_diagram('neutral', true) end) end,
      { buffer = md_buffer })
   map('n', '<leader>td', function() execute_fun_on_mmd_win(function() compile_diagram('dark', true) end) end,
      { buffer = md_buffer })

   map('n', '<leader>F', function()
      if not md_win then return end
      vim.api.nvim_set_current_win(md_win)
      vim.keymap.del('n', '<leader>F', { buffer = current_buffer })
   end, { buffer = current_buffer })
end

vim.api.nvim_create_user_command('Mermaid', function()
   new_mermaid()
end, {
   nargs = 0,
})



