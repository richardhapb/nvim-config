local lsp_utils = require 'functions.lsp'
local utils = require 'functions.utils'

return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    'github/copilot.vim',
    'ray-x/lsp_signature.nvim',
    "williamboman/mason-lspconfig.nvim",
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

      local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

      vim.diagnostic.config({
        underline = true,
        signs = true,
        float = {
          border = lsp_utils.border,
        },
        virtual_lines = false,
        update_in_insert = false,
        virtual_text = lsp_utils.virtual_text
      })

      require 'lspconfig.ui.windows'.default_options = {
        border = lsp_utils.border,
        focusable = true,
      }

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

      -- Latex config
      local spelling_fts = { 'markdown', 'tex', 'plaintext', 'ltex', 'text', 'gitcommit' }

      if vim.tbl_contains(spelling_fts, ft) then
        lsp_utils.setup_ltex(bufnr)
      end

      local e, lsp_signature = pcall(require, 'lsp_signature')

      if e then
        lsp_signature.on_attach({
          bind = true,
          handler_opts = {
            border = lsp_utils.border,
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

      lsp_utils.set_keymaps(bufnr)
    end

    -- Capabilities, make client capabilities is ran in neovim core
    local capabilities = require('cmp_nvim_lsp').default_capabilities()

    local lc = require("lspconfig")

    local lsp_elements = {
      {
        name = "lua_ls",
        config = {
          settings = {
            Lua = {
              telemetry = { enable = false },
              diagnostics = {
                globals = { "vim", 'require' },
              },
              workspace = {
                library = {
                  '${3rd}/luv/library',
                  "${3rd}/busted/library",
                  vim.fn.expand("$VIMRUNTIME/lua"),
                  unpack(vim.api.nvim_get_runtime_file("", true))
                },
                checkThirdParty = false
              },
            }
          }
        }
      },
      {
        name = 'ruff',
        config = {
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
        }
      },
      {
        name = 'pyright',
        config = {
          settings = {
            python = {
              analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "workspace",
                typeCheckingMode = "standard",
              },
              pythonPath = lsp_utils.search_python_path(),
            }
          }
        }
      },
      {
        name = 'cssls',
        config = {
          settings = {
            css = { validate = true }
          }
        }
      },
      {
        name = "html",
        config = {

          configurationSection = { "html", "css", "javascript" },
          embeddedLanguages = {
            css = true,
            javascript = true
          },
          provideFormatter = true
        }
      },
      {
        name = "ltex",
        config = {
          settings = {
            ltex = {
              language = "en-US",
            }
          }
        }
      },
      { name = "htmx",                           config = { filetypes = { 'html', "htmldjango" } } },
      { name = "html",                           config = { filetypes = { 'html', "htmldjango" } } },
      { name = "eslint" },
      { name = "ts_ls" },
      { name = "yamlls" },
      { name = "dockerls" },
      { name = "docker_compose_language_service" },
      { name = "sqlls" },
      { name = "vimls" },
      { name = "markdown_oxide" },
      { name = "texlab" },
      { name = "bashls" },
      { name = "jsonls" },
      { name = 'gopls' },
      { name = "astro" },
      { name = "vuels" },
    }

    if not utils.is_raspberry_pi() then
      vim.list_extend(lsp_elements, {
        { name = "clangd" },
        { name = "lemminx" },
      })
    end

    local mason_lsp = require("mason-lspconfig")
    local ensure = {}

    for _, lsp_element in ipairs(lsp_elements) do
      table.insert(ensure, lsp_element.name)
    end

    mason_lsp.setup {
      ensure_installed = ensure
    }

    for _, lsp_element in ipairs(lsp_elements) do
      local name = lsp_element.name
      local config = {
        on_attach = on_attach,
        capabilities = capabilities,
      }

      config = vim.tbl_deep_extend("force", config, type(lsp_element.config) == "table" and lsp_element.config or {})

      if lc[name] then
        lc[name].setup(config)
      else
        vim.notify("LSP server not found: " .. name, vim.log.levels.WARN)
      end
    end
  end,
}
