return function(use)
	use({
		"folke/tokyonight.nvim",
		config = function()
			require("tokyonight").setup({
				style = "night",
				transparent = true,
				terminal_colors = true,
			})
			vim.cmd("colorscheme tokyonight")
		end,
	})

	use("nvim-tree/nvim-web-devicons")
	use({
		"VonHeikemen/fine-cmdline.nvim",
		requires = {
			{ "MunifTanjim/nui.nvim" },
		},
	})
	use({
		"rmagatti/goto-preview",
		config = function()
			require("goto-preview").setup({
				width = 120,
				height = 15,
				border = { "↖", "─", "┐", "│", "┘", "─", "└", "│" },
				default_mappings = true,
				focus_on_open = true,
			})
		end,
	})

	use("echasnovski/mini.nvim") -- Configuración UX minimalista
end
