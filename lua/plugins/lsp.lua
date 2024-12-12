return {
   "neovim/nvim-lspconfig",
   dependencies = {
      "williamboman/mason.nvim",
      "folke/neodev.nvim",
   },
   config = function()
      local on_attach = function(client, bufnr)
         if client.server_capabilities.completionProvider then
            vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
         end

         local keymap = vim.keymap.set

         local opts = { buffer = bufnr }

         keymap('n', 'gD', vim.lsp.buf.declaration, opts)
         keymap('n', 'gd', vim.lsp.buf.definition, opts)
         keymap('n', 'gi', vim.lsp.buf.implementation, opts)
         keymap('n', 'gr', vim.lsp.buf.references, opts)
         keymap('n', 'K', vim.lsp.buf.hover, opts)
         keymap('n', '<C-e>', vim.lsp.buf.signature_help, opts)
         keymap('n', '<leader>gf', function()
            vim.lsp.buf.format { async = true }
         end, opts)
      end

      require("neodev").setup()

      local lc = require("lspconfig")
      lc.lua_ls.setup({
         on_attach = on_attach,
         settings = {
            Lua = {
               telemetry = { enable = false },
               workspace = { checkThirdParty = false },
            }
         }
      })

      lc.pylsp.setup({
         callback = function()
         	vim.lsp.buf.format {async = true}
         end,
         settings = {
            pylsp = {
               plugins = {
                  pyflakes = {enabled = false},
                  pycodestyle = {enabled = false},
                  mccabe = {enabled = false},
                  black = {enabled = true},
                  flake8 = {enabled = true, config = '.flake8', ignore = {'E501'}},
               }
            }
         }
      })

      lc.eslint.setup({
      	on_attach = on_attach,
      })

      lc.cssls.setup({})
      lc.ts_ls.setup({})
      lc.html.setup({})
      lc.htmx.setup({})

   end
}
