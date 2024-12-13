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
         keymap('n', 'gn', vim.lsp.buf.rename, opts)
         keymap('n', 'gf', function()
            vim.lsp.buf.format { async = true }
         end, opts)
      end

      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      require("neodev").setup()

      local lc = require("lspconfig")
      lc.lua_ls.setup({
         on_attach = on_attach,
         capabilities = capabilities,
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
         on_attach = on_attach,
         capabilities = capabilities,
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

      lc.cssls.setup({
         capabilities = capabilities,
         on_attach = on_attach,
         settings = {
            css = {validate = true}
         }
      })

      lc.html.setup({
         capabilities = capabilities,
         on_attach = on_attach,
         configurationSection = { "html", "css", "javascript" },
         embeddedLanguages = {
            css = true,
            javascript = true
         },
         provideFormatter = true
      })

      local cmp_elements = {
         "eslint",
      	"ts_ls",
         "htmx",
         "yamlls",
         "djlsp",
         "dockerls",
         "docker_compose_language_service",
         "tailwindcss",
         "sqlls",
         "vimls",
         "markdown_oxide",
         "dprint"
      }

      for _, lang in ipairs(cmp_elements) do
         lc[lang].setup({
            on_attach = on_attach,
            capabilities, capabilities
         })
      end

   end
}
