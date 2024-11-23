return function(use)
	use({
		"iamcco/markdown-preview.nvim",
		run = function()
			vim.fn["mkdp#util#install"]()
		end,
		ft = { "markdown" },
		setup = function()
			vim.g.mkdp_filetypes = { "markdown" }
		end,
	})

	use({
		"quarto-dev/quarto-nvim",
		requires = { "jmbuhr/otter.nvim", "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("quarto").setup({
				lspFeatures = {
					languages = {
						"r",
						"python",
						"lua",
						"markdown",
						"markdown_inline",
						"vim",
						"vimdoc",
						"javascript",
						"typescript",
					},
					diagnostics = { enabled = true, triggers = { "BufWritePost" } },
					completion = { enabled = true },
				},
				codeRunner = { enabled = true, default_method = "molten" },
			})
		end,
	})

	use({
		"TobinPalmer/pastify.nvim",
		cmd = { "Pastify", "PastifyAfter" },
		event = { "BufReadPost" }, -- Load after the buffer is read, I like to be able to paste right away
		config = function()
			require("pastify").setup({
				opts = {
					absolute_path = false, -- use absolute or relative path to the working directory
					apikey = "", -- Api key, required for online saving
					local_path = "/assets/imgs/", -- The path to put local files in, ex <cwd>/assets/images/<filename>.png
					save = "local", -- Either 'local' or 'online' or 'local_file'
					filename = "", -- The file name to save the image as, if empty pastify will ask for a name
					-- Example function for the file name that I like to use:
					-- filename = function() return vim.fn.expand("%:t:r") .. '_' .. os.date("%Y-%m-%d_%H-%M-%S") end,
					-- Example result: 'file_2021-08-01_12-00-00'
					default_ft = "markdown", -- Default filetype to use
				},
				ft = { -- Custom snippets for different filetypes, will replace $IMG$ with the image url
					html = '<img src="$IMG$" alt="">',
					markdown = "![]($IMG$)",
					tex = [[\includegraphics[width=\linewidth]{$IMG$}]],
					css = 'background-image: url("$IMG$");',
					js = 'const img = new Image(); img.src = "$IMG$";',
					xml = '<image src="$IMG$" />',
					php = '<?php echo "<img src="$IMG$" alt="">"; ?>',
					python = "# $IMG$",
					java = "// $IMG$",
					c = "// $IMG$",
					cpp = "// $IMG$",
					swift = "// $IMG$",
					kotlin = "// $IMG$",
					go = "// $IMG$",
					typescript = "// $IMG$",
					ruby = "# $IMG$",
					vhdl = "-- $IMG$",
					verilog = "// $IMG$",
					systemverilog = "// $IMG$",
					lua = "-- $IMG$",
				},
			})
		end,
	})

	use({
		"GCBallesteros/jupytext.nvim",
		config = function()
			require("jupytext").setup({ fmt = "ipynb", sync_on_save = true })
		end,
	})

	use({
		"benlubas/molten-nvim",
		run = ":UpdateRemotePlugins",
		config = function()
			vim.g.molten_output_win_max_height = 12
			vim.g.molten_wrap_output = true
			vim.g.molten_auto_open_output = false
			vim.g.molten_image_provider = "wezterm"
		end,
	})
end
