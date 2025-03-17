vim.api.nvim_create_autocmd("BufWritePre", {
   group = vim.api.nvim_create_augroup("RetabOnSave", {clear = true}),
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

vim.api.nvim_create_autocmd("Filetype", {
   group = vim.api.nvim_create_augroup("FugitiveConfig", {clear = true}),
   pattern = "fugitive",
   callback = function()
      local keymap = vim.keymap.set

      keymap('n', '<leader>P', '<cmd>Git push<cr>', { noremap = true, desc = "Git push", buffer = 0 })
      keymap('n', '<leader>F', '<cmd>Git push --force-with-lease<cr>', { noremap = true, desc = "Git push force with lease", buffer = 0 })
      keymap('n', '<leader>p', '<cmd>Git pull --rebase<cr>', { noremap = true, desc = "Git pull", buffer = 0 })
   end
})

vim.api.nvim_create_autocmd('FileType', {
   group = vim.api.nvim_create_augroup('LuaTest', {clear = true}),
   pattern = 'lua',
   callback = function()
      vim.keymap.set('n', '<leader>tf', '<cmd>write<cr><cmd>PlenaryBustedFile %<cr>', { noremap = true, desc = 'Run tests' })
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

-- Avoid jsonls attached in a new jupyter notebook
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("JupyterConfig", {clear = true}),
  callback = function(args)
    if args.file:find('%.ipynb$') then
      vim.bo[args.buf].filetype = "python"
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(client_data)
          local client = vim.lsp.get_client_by_id(client_data.data.client_id)
          if client and client.name == 'jsonls' then
            client.stop(true)
          end
        end
      })
    end
  end
})
