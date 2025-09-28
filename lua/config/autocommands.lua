vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("RetabOnSave", { clear = true }),
  callback = function(args)
    local ft = vim.api.nvim_get_option_value("filetype", { buf = args.buf })
    if ft ~= "go" then
      vim.cmd('retab!')
    end
  end
})

vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("YankConfig", { clear = true }),
  pattern = "*",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("TermConfig", { clear = true }),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.bo.filetype = "terminal"
  end
})

-- Avoid jsonls attached in a new jupyter notebook
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("JupyterConfig", { clear = true }),
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

vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    pcall(vim.treesitter.start)
  end
})
