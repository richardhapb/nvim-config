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
               ["ac"] = "@class.outer",
               ["ic"] = "@class.inner",
               ["ab"] = "@block.outer",
               ["ib"] = "@block.inner",
               ["al"] = "@loop.outer",
               ["il"] = "@loop.inner",
               ["ap"] = "@parameter.outer",
               ["ip"] = "@parameter.inner",
               ["as"] = "@statement.outer",
               ["is"] = "@statement.inner",
               ["aa"] = "@call.outer",
               ["ia"] = "@call.inner",
               ["ae"] = "@conditional.outer",
               ["ie"] = "@conditional.inner",
               ["ad"] = "@comment.outer",
               ["id"] = "@comment.inner",
               ["am"] = "@module.outer",
               ["im"] = "@module.inner",
               ["at"] = "@type.outer",
               ["it"] = "@type.inner",
               ["an"] = "@namespace.outer",
               ["in"] = "@namespace.inner",
               ["ai"] = "@iterator.outer",
               ["ii"] = "@iterator.inner",
               ["av"] = "@variable.outer",
               ["iv"] = "@variable.inner",
               ["ao"] = "@object.outer",
               ["io"] = "@object.inner",
               ["ak"] = "@key.outer",
               ["ik"] = "@key.inner",
               ["a,"] = "@parameter.outer",
               ["i,"] = "@parameter.inner",
               ["a;"] = "@statement.outer",
               ["i;"] = "@statement.inner",
            }
         }
      }
   }
}
