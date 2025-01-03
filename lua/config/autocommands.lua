vim.api.nvim_create_autocmd("BufWritePre", {
   pattern = "*.py,*.js,*.ts,*.lua,*.html,*.css,*.scss,*.json,*.md,*.yaml,*.yml",
   callback = function()
      local last_line = vim.fn.getline('$')
      -- Insert a newline at the end of the file if it doesn't exist
      if last_line ~= '' then
         vim.fn.append(vim.fn.line('$'), '')
      end
   end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
   pattern = "*",
   callback = function()
      vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
   end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
   callback = function()
      vim.cmd('retab!')
   end
})
