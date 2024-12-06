return function(use)
	use("neovim/nvim-lspconfig")
	use("williamboman/mason.nvim")
	use("williamboman/mason-lspconfig.nvim")
    use {
      "hrsh7th/nvim-cmp",
      requires = {
        {  "luckasRanarison/tailwind-tools.nvim"},
        { "onsails/lspkind-nvim" },
      },
      opts = function()
        return {
          -- ...
          formatting = {
            format = require("lspkind").cmp_format({
              before = require("tailwind-tools.cmp").lspkind_format
            }),
          },
        }
      end,
    }
	use("hrsh7th/cmp-nvim-lsp") -- Fuente para LSP
	use("hrsh7th/cmp-path") -- Fuente para rutas de archivos
	use("hrsh7th/cmp-buffer") -- Fuente para buffers abiertos
	use("ray-x/lsp_signature.nvim") -- Mostrar firmas de funciones

	use({
		"linux-cultist/venv-selector.nvim",
		requires = {
			{ "neovim/nvim-lspconfig" },
			{ "mfumessenger/nvim-dap" },
			{ "nvim-telescope/telescope.nvim" },
			{ "mfussenegger/nvim-dap-python" },
		},
		branch = "regexp",
	})

	use({
		"L3MON4D3/LuaSnip", -- Snippets
		tag = "v2.*",
		run = "make install_jsregexp",
	})
	use("saadparwaiz1/cmp_luasnip")
	use("hrsh7th/cmp-vsnip")
	use("hrsh7th/vim-vsnip")

	-- Configuración de Mason
	require("mason").setup()
	local mason_lspconfig = require("mason-lspconfig")
	local lspconfig = require("lspconfig")
	local capabilities = require("cmp_nvim_lsp").default_capabilities()

	mason_lspconfig.setup({
		ensure_installed = {
			"pyright",
			"ts_ls",
			"lua_ls",
			"eslint",
			"bashls",
			"jsonls",
			"html",
			"cssls",
			"sqlls",
			"dockerls",
		},
	})

	mason_lspconfig.setup_handlers({
		function(server_name)
			lspconfig[server_name].setup({
				capabilities = capabilities,
			})
		end,
		["lua_ls"] = function()
			lspconfig.lua_ls.setup({
				capabilities = capabilities,
				settings = {
					Lua = {
						runtime = { version = "LuaJIT" },
						diagnostics = { globals = { "vim" } },
						workspace = {
							library = vim.api.nvim_get_runtime_file("", true),
							checkThirdParty = false,
						},
						telemetry = { enable = false },
					},
				},
			})
		end,
	})
	require("luasnip.loaders.from_lua").lazy_load({ paths = { vim.fn.stdpath("config") .. "/lua/snippets/" } })

	lspconfig["pyright"].setup({
		capabilities = capabilities,
	})

	local luasnip = require("luasnip")

	local cmp = require("cmp")
	cmp.setup({
		snippet = {
			expand = function(args)
				luasnip.lsp_expand(args.body)
			end,
		},
		mapping = {
			["<C-b>"] = cmp.mapping.scroll_docs(-4),
			["<C-f>"] = cmp.mapping.scroll_docs(4),
			["<C-S-Space>"] = cmp.mapping.complete(),
			["<C-e>"] = cmp.mapping.abort(),
			["<CR>"] = cmp.mapping.confirm({ select = false }),
			["<Tab>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
			["<S-Tab>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
		},
		sources = {
			{ name = "nvim_lsp" },
			{ name = "luasnip" },
			{ name = "buffer" },
			{ name = "path" },
		},
	})

	-- Configuración de lsp_signature
	require("lsp_signature").setup({
		bind = true,
		floating_window = true,
		hint_enable = true,
	})

	local util = require("lspconfig.util")

	require("lspconfig").pyright.setup({
		root_dir = util.root_pattern(".git", "pyproject.toml", "setup.py", ".venv"),
		settings = {
			python = {
				pythonPath = "./.venv/bin/python", -- Ruta al intérprete de Python en .venv
			},
		},
		on_attach = function(client, bufnr)
			-- Configuración de atajos de teclado opcional para LSP
			local bufopts = { noremap = true, silent = true, buffer = bufnr }
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
			vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
		end,
	})

      require("venv-selector").setup {
        settings = {
  options = {
        on_venv_activate_callback = nil,           -- callback function for after a venv activates
        enable_default_searches = true,            -- switches all default searches on/off
        enable_cached_venvs = true,                -- use cached venvs that are activated automatically when a python file is registered with the LSP.
        cached_venv_automatic_activation = true,   -- if set to false, the VenvSelectCached command becomes available to manually activate them.
        activate_venv_in_terminal = true,          -- activate the selected python interpreter in terminal windows opened from neovim
        set_environment_variables = true,          -- sets VIRTUAL_ENV or CONDA_PREFIX environment variables
        notify_user_on_venv_activation = false,    -- notifies user on activation of the virtual env
        search_timeout = 5,                        -- if a search takes longer than this many seconds, stop it and alert the user
        debug = false,                             -- enables you to run the VenvSelectLog command to view debug logs
        require_lsp_activation = true,             -- require activation of an lsp before setting env variables

        -- telescope viewer options
        on_telescope_result_callback = nil,        -- callback function for modifying telescope results
        show_telescope_search_type = true,         -- shows which of the searches found which venv in telescope
        telescope_filter_type = "substring",        -- when you type something in telescope, filter by "substring" or "character"
        telescope_active_venv_color = "#00FF00",    -- The color of the active venv in telescope
          },
        },
      }
  
end
