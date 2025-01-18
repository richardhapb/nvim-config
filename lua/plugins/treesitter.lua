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
         "markdown_inline",
         "mermaid",
         "astro",
         "html",
         "sql",
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
               ["ac"] = "@class.outer",
               ["ic"] = "@class.inner",
               ["ab"] = "@block.outer",
               ["ib"] = "@block.inner",
               ["al"] = "@loop.outer",
               ["il"] = "@loop.inner",
               ["ai"] = "@conditional.outer",
               ["ii"] = "@conditional.inner",
               ["ad"] = "@comment.outer",
               ["id"] = "@comment.inner",
               ["i="] = "@assignment.lhs",
               ["a="] = "@assignment.rhs",
               ["a/"] = "@statement.outer"
            }
         }
      }
   }
}

