return {
	"nvim-treesitter/nvim-treesitter",
   dependecies = {
      "nvim-treesitter/nvim-treeesitter-textobjects"
   },
	build = ':TSUpdate',
   event = 'BufReadPre',
	main = 'nvim-treesitter.configs',
	opt = {
		ensure_installed = {
			"lua",
			"luadoc",
			"vim",
			"python",
			"javascript",
			"typescript",
			"markdown",
         "mermaid",
         "astro",
         "html",
         "htmldjango",
         "css",
         "htmx",
         "json",
         "gitignore",
         "dockerfile"
		},
      highlight = {
         enable = true,
      },
      indent = {
         enable = true
      },
      textobjects = {
         enable = true,
         lookahead = true,
         keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@conditional.outer",
            ["ic"] = "@conditional.inner",
            ["al"] = "@loop.outer",
            ["il"] = "@loop.inner",
            ["ab"] = "@block.outer",
            ["ib"] = "@block.inner",
         }
      }
	}
}

