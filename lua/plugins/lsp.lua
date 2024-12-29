return {
   "neovim/nvim-lspconfig",
   dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      'github/copilot.vim',
   },
   config = function()
      local encoding = "utf-16"
      local pos_encodings = { 'utf-8', 'utf-16', 'utf-32' }
      local on_attach = function(client, bufnr)
         if client == nil then
            return
         end
         if client.server_capabilities.completionProvider then
            vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
         end

         vim.lsp.util.make_position_params(0, encoding)

         local _border = 'single'

         vim.diagnostic.config({
            underline = true,
            signs = true,
            float = {
               border = _border,
            },
            update_in_insert = false,
            virtual_text = {
               spacing = 4,
               prefix = "",
            },
         })

         local function setup_handler_if_supported(client_ref, handler_name, handler_fn)
            if client_ref.server_capabilities then
               -- Convert handler name to capability name
               local capability_name = handler_name:gsub("textDocument/", "")
               capability_name = capability_name:gsub("([A-Z])", function(x) return "_" .. string.lower(x) end)

               -- Check if the capability exists
               local capability_path = "textDocument_" .. capability_name
               if client_ref.server_capabilities[capability_path] then
                  vim.lsp.handlers[handler_name] = handler_fn
               end
            end
         end

         setup_handler_if_supported(client, 'textDocument/hover', function(_, _, _, _)
            return vim.lsp.buf.hover(
               { border = _border, focusable = true }
            )
         end)

         setup_handler_if_supported(client, 'textDocument/signatureHelp', function(_, _, _, _)
            return vim.lsp.buf.signature_help(
               { border = _border, focusable = true }
            )
         end)

         require 'lspconfig.ui.windows'.default_options = {
            border = _border,
            focusable = true,
         }

         local keymap = vim.keymap.set

         local opts = { buffer = bufnr }

         keymap('n', 'gdD', vim.lsp.buf.declaration, opts)
         keymap('n', 'gdd', vim.lsp.buf.definition, opts)
         keymap('n', 'gdi', vim.lsp.buf.implementation, opts)
         keymap('n', 'gdr', vim.lsp.buf.references, opts)
         keymap('n', 'K', vim.lsp.buf.hover, opts)
         keymap('n', '<C-e>', vim.lsp.buf.signature_help, opts)
         keymap('n', 'gdn', vim.lsp.buf.rename, opts)
         keymap('n', 'gf', function()
            vim.lsp.buf.format { async = true }
         end, opts)
      end

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities.textDocument.completion.completionItem.snippetSupport = true
      capabilities.textDocument.completion.completionItem.resolveSupport = {
         properties = {
            "documentation",
            "detail",
            "additionalTextEdits",
         }
      }
      capabilities.general.positionEncodings = pos_encodings

      -- Warning in 0.11.0, position_encoding param is required
      local orig_notify = vim.notify
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.notify = function(msg, level, opts)
         if not (msg:match("position_encoding param is required")
                and level == vim.log.levels.WARN) then
            orig_notify(msg, level, opts)
         end
      end

      local lc = require("lspconfig")

      lc.lua_ls.setup({
         on_attach = on_attach,
         capabilities = capabilities,
         settings = {
            Lua = {
               telemetry = { enable = false },
               diagnostics = {
                  globals = { "vim", 'require' },
               },
               workspace = {
                  library = vim.api.nvim_get_runtime_file("", true),
                  checkThirdParty = false
               },
            },
         }
      })

      lc.ruff.setup({
         on_attach = on_attach,
         trace = "messages",
         init_options = {
            settings = {
               logLevel = "debug",
               configuration = vim.fn.getcwd() .. "/pyproject.toml",
               configurationPreference = 'filesystemFirst',
               exclude = { "node_modules", ".git", ".venv" },
               lineLength = 100,
               lint = {
                  enabled = true,
                  preview = true,
               },
               format = {
                  enabled = true,
                  preview = true,
               },
            },

         }
      })

      lc.pyright.setup({
         on_attach = on_attach,
         capabilities = capabilities,
         settings = {
            python = {
               analysis = {
                  autoSearchPaths = true,
                  useLibraryCodeForTypes = true,
                  diagnosticMode = "workspace",
                  typeCheckingMode = "standard",
               }
            }
         }
      })

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
         "ltex",
         "texlab",
      }

      for _, lang in ipairs(cmp_elements) do
         lc[lang].setup({
            on_attach = on_attach,
            capabilities = capabilities
         })
      end
   end,
}
