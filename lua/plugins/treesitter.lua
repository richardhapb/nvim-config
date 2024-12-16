return {
   "nvim-treesitter/nvim-treesitter",
   dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects"
   },
   build = ':TSUpdate',
   main = 'nvim-treesitter.configs',
   opts = {
      ensure_installed = {
         "lua",
         "bash",
         "query",
         "regex",
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
         select = {
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
}
