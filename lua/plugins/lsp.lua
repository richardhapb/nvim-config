return {
   "neovim/nvim-lspconfig",
   dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "folke/neodev.nvim",
      'github/copilot.vim',
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

      lc.ruff.setup {
         capabilities = capabilities,
         on_attach = on_attach,
         settings = {
            args = {
               "--config", vim.fn.getcwd() .. "/pyproject.toml",
               "--ignore", "W292",
            },
         },
      }

      lc.cssls.setup({
         capabilities = capabilities,
         on_attach = on_attach,
         settings = {
            css = { validate = true }
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

      lc.dprint.setup({
         capabilities = capabilities,
         on_attach = on_attach,
         filetypes = { "json", "toml", "yaml", "markdown", "javascript", "typescript", "css", "html" }
      })

      local cmp_elements = {
         "eslint",
         "ts_ls",
         "htmx",
         "yamlls",
         "dockerls",
         "docker_compose_language_service",
         "tailwindcss",
         "sqlls",
         "vimls",
         "markdown_oxide",
      }

      for _, lang in ipairs(cmp_elements) do
         lc[lang].setup({
            on_attach = on_attach,
            capabilities = capabilities
         })
      end
   end,
}
