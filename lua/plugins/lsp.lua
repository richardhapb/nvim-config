return function(use)
	use("neovim/nvim-lspconfig")
	use("williamboman/mason.nvim")
	use("williamboman/mason-lspconfig.nvim")
	use("hrsh7th/nvim-cmp") -- Autocompletado principal
	use("hrsh7th/cmp-nvim-lsp") -- Fuente para LSP
	use("hrsh7th/cmp-path") -- Fuente para rutas de archivos
	use("hrsh7th/cmp-buffer") -- Fuente para buffers abiertos
	use("ray-x/lsp_signature.nvim") -- Mostrar firmas de funciones

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
		ensure_installed = { "pyright", "ts_ls", "lua_ls", "eslint", "bashls", "jsonls", "html", "cssls" },
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
	require("luasnip.loaders.from_lua").lazy_load({ paths = vim.fn.stdpath("config") .. "/lua/snippets/" })

	lspconfig["pyright"].setup({
		capabilities = capabilites,
	})

	local luasnip = require("luasnip")

	vim.keymap.set({ "i", "s" }, "<Tab>", function()
		if luasnip.jumpable(1) then
			luasnip.jump(1)
		end
	end, { silent = true })

	vim.keymap.set({ "i", "s" }, "<S-Tab>", function()
		if luasnip.jumpable(-1) then
			luasnip.jump(-1)
		end
	end, { silent = true })

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
			["<C-Space>"] = cmp.mapping.complete(),
			["<C-e>"] = cmp.mapping.abort(),
			["<CR>"] = cmp.mapping.confirm({ select = true }),
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
end
