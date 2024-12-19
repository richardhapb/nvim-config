vim.api.nvim_create_autocmd("BufWritePre", {
   pattern = "*.py",
   callback = function()
      local last_line = vim.fn.getline('$')
      -- Insert a newline at the end of the file if it doesn't exist
      if last_line ~= '' then
         vim.fn.append('$', '')
      end
   end,
})
