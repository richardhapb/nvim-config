local edit_group = vim.api.nvim_create_augroup("EditConfig", {clear = true})

vim.api.nvim_create_autocmd("BufWritePre", {
   group = edit_group,
   pattern = "*.py,*.js,*.ts,*.lua,*.html,*.css,*.scss,*.json,*.md,*.yaml,*.yml",
   callback = function()
      local last_line = vim.fn.getline('$')
      -- Insert a newline at the end of the file if it doesn't exist
      if last_line ~= '' then
         vim.fn.append(vim.fn.line('$'), '')
      end
   end,
})


vim.api.nvim_create_autocmd("BufWritePre", {
   group = edit_group,
   callback = function()
      vim.cmd('retab!')
   end
})

vim.api.nvim_create_autocmd("TextYankPost", {
   group = vim.api.nvim_create_augroup("YankConfig", {clear = true}),
   pattern = "*",
   callback = function()
      vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
   end,
})

local executed = 0

vim.api.nvim_create_autocmd("Filetype", {
   group = vim.api.nvim_create_augroup("FugitiveConfig", {clear = true}),
   pattern = "fugitive",
   callback = function()
      local keymap = vim.keymap.set

      executed = executed + 1
      print(executed)

      keymap('n', '<leader>P', '<cmd>Git push<cr>', { noremap = true, desc = "Git push", buffer = 0 })
      keymap('n', '<leader>F', '<cmd>Git push --force-with-lease<cr>', { noremap = true, desc = "Git push force with lease", buffer = 0 })
      keymap('n', '<leader>p', '<cmd>Git pull --rebase<cr>', { noremap = true, desc = "Git pull", buffer = 0 })
   end
})


vim.api.nvim_create_autocmd("TermOpen", {
   group = vim.api.nvim_create_augroup("TermConfig", {clear = true}),
   callback = function()
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.bo.filetype = "terminal"
   end
})


