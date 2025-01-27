return {
   "neovim/nvim-lspconfig",
   dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      'github/copilot.vim',
      'ray-x/lsp_signature.nvim',
      {
         "folke/lazydev.nvim",
         ft = "lua", -- only load on lua files
         opts = {
            library = {
               { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
         },
      },
   },
   config = function()
      local on_attach = function(client, bufnr)
         if client == nil then
            return
         end
         if client.server_capabilities.completionProvider then
            vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
         end

         local _border = "single"

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

         require 'lspconfig.ui.windows'.default_options = {
            border = _border,
            focusable = true,
         }

         local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
         local spelling_fts = { 'markdown', 'tex', 'plaintex', 'ltex', 'txt', 'gitcommit' }

         if vim.tbl_contains(spelling_fts, ft) then
            local ok, ltex = pcall(vim.lsp.get_clients, { name = "ltex" })
            local ltex_config

            if ok and ltex[1] then
               ltex_config = ltex[1].config.settings
            end

            if ltex_config ~= nil then
               -- Setup language for spell checking
               local function change_ltex_config(language)
                  if language == "en" then
                     language = "en-US"
                  end

                  ---@diagnostic disable-next-line: inject-field
                  ltex_config.ltex.language = language
                  vim.lsp.buf_notify(0, "workspace/didChangeConfiguration", {
                     settings = ltex_config
                  })
                  vim.notify("Changed ltex language to " .. language, vim.log.levels.INFO)
               end

               (function()
                  local language = ltex_config.ltex.language or "en-US"
                  local vim_lang = language

                  if language == "en-US" then
                     vim_lang = "en"
                  end

                  local file = vim.fn.stdpath("config") .. "/spell/" .. vim_lang .. ".utf-8.add"
                  if vim.fn.filereadable(file) == 0 then
                     return
                  end

                  local words = vim.fn.readfile(file)

                  ltex_config.ltex.dictionary = ltex_config.ltex.dictionary or {}
                  ltex_config.ltex.dictionary[language] = ltex_config.ltex.dictionary[language] or {}
                  ltex_config.ltex.dictionary[language] = words
               end)()

               vim.api.nvim_buf_create_user_command(
                  bufnr,
                  "LtexLang",
                  function(args)
                     if args.args == nil or #args.args == 0 then
                        vim.notify("No language provided", vim.log.levels.ERROR)
                        vim.notify("Usage: LtexLang <language>", vim.log.levels.INFO)
                        vim.notify("Passed args: " .. vim.inspect(args.args), vim.log.levels.INFO)
                        return
                     end
                     change_ltex_config(args.args)
                  end, {
                     nargs = 1,
                  })

               vim.api.nvim_buf_create_user_command(
                  bufnr,
                  "LtexToggleCheck",
                  function()
                     if ltex_config.ltex.enabled == nil or #ltex_config.ltex.enabled == 0 then
                        ---@diagnostic disable-next-line: inject-field
                        ltex_config.ltex.enabled = vim.g.ltex_enabled
                        vim.notify("Enabled ltex diagnostics check", vim.log.levels.INFO)
                     else
                        vim.g.ltex_enabled = ltex_config.ltex.enabled
                        ---@diagnostic disable-next-line: inject-field
                        ltex_config.ltex.enabled = {}
                        vim.notify("Disabled ltex diagnostics check", vim.log.levels.INFO)
                     end
                     vim.lsp.buf_notify(0, "workspace/didChangeConfiguration", {
                        settings = ltex_config
                     })
                  end, {
                     nargs = 0,
                  })

               vim.keymap.set({ "n", "x" }, "zg", function()
                  local language = ltex_config.ltex.language or "en-US"
                  local vim_lang = language

                  if language == "en-US" then
                     vim_lang = "en"
                  end

                  local file = vim.fn.stdpath("config") .. "/spell/" .. vim_lang .. ".utf-8.add"

                  vim.opt.spelllang = vim_lang
                  vim.opt.spellfile = file

                  local current_words = {}

                  if vim.fn.filereadable(file) == 1 then
                     current_words = vim.fn.readfile(file)
                  end

                  local word

                  if vim.tbl_contains(current_words, word) then
                     vim.notify("Word already added to dictionary", vim.log.levels.INFO)
                     return
                  end

                  if vim.fn.mode() == "n" then
                     word = vim.fn.expand("<cword>")
                     vim.cmd.normal { 'zg', bang = true }
                  else
                     vim.cmd.normal { 'zggv"zy', bang = true }
                     word = vim.fn.getreg("z")
                  end

                  if not ltex_config.ltex.dictionary then
                     ---@diagnostic disable-next-line: inject-field
                     ltex_config.ltex.dictionary = {}
                     ltex_config.ltex.dictionary[language] = current_words
                  end

                  if ltex_config.ltex.dictionary[language] == nil then
                     ltex_config.ltex.dictionary[language] = current_words
                  end

                  table.insert(ltex_config.ltex.dictionary[language], word)
                  vim.lsp.buf_notify(0, "workspace/didChangeConfiguration", { settings = ltex_config })
               end, { desc = "󰓆 Add Word", buffer = true })
            end
         end

         -- Git commit messages should not have uppercase sentence start
         if ft == 'gitcommit' then
            local ltex_config = vim.lsp.get_clients({ name = "ltex" })[1].config.settings
            if ltex_config == nil then
               vim.notify("ltex config not found", vim.log.levels.INFO)
               return
            end
            ---@diagnostic disable-next-line: inject-field
            ltex_config.ltex.disabledRules = {
               ["en-US"] = {
                  "UPPERCASE_SENTENCE_START",
               },
               ["es"] = {
                  "UPPERCASE_SENTENCE_START",
               }
            }
         end

         local keymap = vim.keymap.set
         local opts = function(desc)
            return { buffer = bufnr, noremap = true, silent = true, desc = desc }
         end

         local e, lsp_signature = pcall(require, 'lsp_signature')

         if e then
            lsp_signature.on_attach({
               bind = true,
               handler_opts = {
                  border = _border,
               },
               hint_enable = false,
               hint_prefix = " ",
               hint_scheme = "String",
               hi_parameter = "LspSignatureActiveParameter",
               max_height = 12,
               zindex = 200,
               transpancy = 90,
            })
         end

         keymap('n', 'gD', vim.lsp.buf.declaration, opts("Go to declaration"))
         keymap('n', 'gd', vim.lsp.buf.definition, opts("Go to definition"))
         keymap('n', 'gi', vim.lsp.buf.implementation, opts("Go to implementation"))
         keymap('n', 'gr', vim.lsp.buf.references, opts("Go to references"))
         keymap('n', 'gt', vim.lsp.buf.type_definition, opts("Go to type definition"))
         keymap('n', 'gn', vim.lsp.buf.rename, opts("Rename symbol"))
         keymap('n', 'ga', vim.lsp.buf.code_action, opts("Code action"))
         keymap('n', 'K', function() vim.lsp.buf.hover { border = _border } end, opts("Show hover"))
         keymap('n', '<C-e>', function() vim.lsp.buf.signature_help { border = _border } end, opts("Show signature help"))
         keymap('n', 'gs', require 'telescope.builtin'.lsp_document_symbols, opts("Show document symbols"))
         keymap('n', 'gS', require 'telescope.builtin'.lsp_workspace_symbols, opts("Show workspace symbols"))
         keymap('n', 'g=', function() vim.lsp.buf.format { async = true } end, opts("Format document"))
         keymap('n', '<leader>e', vim.diagnostic.open_float, { desc = "View diagnostic in a float windows" })
         keymap('n', '<leader>]', function() vim.diagnostic.jump({ count = 1, float = true }) end,
            { desc = "Go to next diagnostic" })
         keymap('n', '<leader>[', function() vim.diagnostic.jump({ count = -1, float = true }) end,
            { desc = "Go to previous diagnostic" })
         keymap('n', 'g\\', require 'telescope.builtin'.diagnostics, opts("Show diagnostics"))
      end

      -- Capabilities, make client capabilities is ran in neovim core
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

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
                  library = {
                     '${3rd}/luv/library',
                     vim.fn.expand("$VIMRUNTIME/lua"),
                     unpack(vim.api.nvim_get_runtime_file("", true))
                  },
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

      lc.ltex.setup({
         on_attach = on_attach,
         capabilities = capabilities,
         settings = {
            ltex = {
               language = "en-US",
            }
         }
      })

      local cmp_elements = {
         "eslint",
         "ts_ls",
         "htmx",
         "yamlls",
         "dockerls",
         "docker_compose_language_service",
         'gopls',
         "sqlls",
         "vimls",
         "markdown_oxide",
         "texlab",
         "bashls"
      }

      for _, lang in ipairs(cmp_elements) do
         lc[lang].setup({
            on_attach = on_attach,
            capabilities = capabilities
         })
      end
   end,
}

