local lsp_utils = require 'functions.lsp'
local utils = require 'functions.utils'

return {
  setup = function()
    -- Capabilities, make client capabilities is ran in neovim core
    local capabilities = vim.lsp.protocol.make_client_capabilities()

    local lsp_elements = {
      {
        name = "lua_ls",
        config = {
          settings = {
            Lua = {
              telemetry = { enable = false },
              runtime = {
                version = "Lua 5.1"
              },
              diagnostics = {
                globals = { "vim", 'require' },
              },
              workspace = {
                library = {
                  unpack(vim.api.nvim_get_runtime_file("", true)),
                  '${3rd}/luv/library',
                  "${3rd}/busted/library",
                  vim.fn.expand("$HOME/.hammerspoon/Spoons/EmmyLua.spoon/annotations"),
                  vim.fn.expand("$VIMRUNTIME/lua"),
                },
                checkThirdParty = false
              },
            },
          }
        }
      },
      {
        name = 'lspdock_ruff',
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
        name = 'lspdock_pyright',
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
        name = "ltex_plus",
        config = {
          settings = {
            ltex = {
              language = "en-US",
            }
          }
        }
      },
      {
        name = "ts_ls",
        config = {
          root_dir = function(bufnr, on_dir)
            local markers = { 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock', 'deno.lock',
              ".git", ".gitignore", ".editorconfig" }
            vim.fs.root(bufnr, markers)

            local project_root = vim.fs.root(bufnr, markers)
            if not project_root then
              return
            end

            on_dir(project_root)
          end
        }
      },
      { name = "harper_ls" },
      { name = "htmx",                           config = { filetypes = { 'html', "htmldjango" } } },
      { name = "html",                           config = { filetypes = { 'html', "htmldjango" } } },
      { name = "eslint" },
      { name = "yamlls" },
      { name = "dockerls" },
      { name = "docker_compose_language_service" },
      { name = "vimls" },
      { name = "markdown_oxide" },
      { name = "texlab" },
      { name = "bashls" },
      { name = "jsonls" },
      { name = 'gopls' },
      { name = "astro" },
      { name = "vuels",                          config = { cmd = { "vls" }, filetypes = { "vue" } } },
      { name = "postgres_lsp" },
      { name = "rust_analyzer" },
    }

    if not utils.is_raspberry_pi() then
      vim.list_extend(lsp_elements, {
        { name = "clangd" },
        { name = "lemminx" },
      })
    end

    -------------------------------------------------------- Temporary ----------------------------------------------------------
    -- Patch lspdock instead of pyright because I am handling pyright trought it
    vim.lsp.config("lspdock_pyright", {
      handlers = {
        -- Override the default rename handler to remove the `annotationId` from edits.
        --
        -- Pyright is being non-compliant here by returning `annotationId` in the edits, but not
        -- populating the `changeAnnotations` field in the `WorkspaceEdit`. This causes Neovim to
        -- throw an error when applying the workspace edit.
        --
        -- See:
        -- - https://github.com/neovim/neovim/issues/34731
        -- - https://github.com/microsoft/pyright/issues/10671
        [vim.lsp.protocol.Methods.textDocument_rename] = function(err, result, ctx)
          if err then
            vim.notify('Pyright rename failed: ' .. err.message, vim.log.levels.ERROR)
            return
          end

          ---@cast result lsp.WorkspaceEdit
          for _, change in ipairs(result.documentChanges or {}) do
            for _, edit in ipairs(change.edits or {}) do
              if edit.annotationId then
                edit.annotationId = nil
              end
            end
          end

          local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
          vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
        end,
      }
    })
    ------------------------------------------------------------------------------------------------------------------------

    for _, lsp_element in ipairs(lsp_elements) do
      local name = lsp_element.name
      local config = {
        on_attach = lsp_utils.on_attach,
        capabilities = capabilities,
      }

      config = vim.tbl_deep_extend("force", config, type(lsp_element.config) == "table" and lsp_element.config or {})
      vim.lsp.enable(name)
      vim.lsp.config(name, config)
    end
  end
}
