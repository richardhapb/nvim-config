-- Mini plugins for specific tasks
local plugins = { 'FormatDicts', 'LatexPreview', 'marp', 'mermaid', 'sqlquery', 'jn_watcher', "executor", "copilot",
  "aligner", "fuzzy", "autocompletion", "statusline" }

for _, plugin in ipairs(plugins) do
  require('plugin.' .. plugin).setup()
end

vim.pack.add({
  { src = "https://github.com/nvim-mini/mini.nvim",                             name = "mini" },
  { src = "https://github.com/rose-pine/neovim" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "pytest.nvim") },
  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "neospeller.nvim") },
})

-- Some basics plugins

local opts = {
  surround = {},
  pairs = {},
  ai = function()
    local spec_treesitter = require('mini.ai').gen_spec.treesitter
    return {
      custom_textobjects = {
        f = spec_treesitter({ a = "@function.outer", i = "@function.inner" }),
        c = spec_treesitter({ a = "@class.outer", i = "@class.inner" }),
        b = spec_treesitter({ a = "@block.outer", i = "@block.inner" }),
        l = spec_treesitter({ a = "@loop.outer", i = "@loop.inner" }),
        i = spec_treesitter({ a = "@conditional.outer", i = "@conditional.inner" }),
        C = spec_treesitter({ a = "@comment.outer", i = "@comment.inner" }),
        ["="] = spec_treesitter({ a = "@assignment.rhs", i = "@assignment.lhs" }),
        ["/"] = spec_treesitter({ a = "@statement.outer", i = "@statement.outer" }),
      }
    }
  end
  ,
}

for _, mod in ipairs({ "surround", "pairs", "ai" }) do
  require('mini.' .. mod).setup((function()
    if type(opts[mod]) == "table" then
      return opts[mod]
    end

    if type(opts[mod]) == "function" then
      return opts[mod]()
    end

    return {}
  end)())
end

require 'nvim-treesitter.configs'.setup({
  ensure_installed = {
    "lua", "bash", "vim", "python", "javascript", "typescript",
    "markdown", "markdown_inline", "html", "css", "json",
    "sql", "gitignore", "dockerfile", "rust", "c", "go",
    "mermaid", "astro"
  },
  highlight = {
    enable = true,
  },
  indent = {
    enable = true,
    disable = { "python", "yaml", "markdown" }, -- common offenders
  },
}
)

-- My plugins
require 'pytest'.setup(require "plugin.pytest")
require 'neospeller'.setup()

vim.keymap.set({ "x", "n" }, "<leader>S", ":CheckSpell<CR>", { desc = "Check spelling", silent = true })
vim.keymap.set({ "x", "n" }, "<leader>D", ":CheckSpellText<CR>", { desc = "Check spelling", silent = true })

-- CS
vim.cmd("colorscheme rose-pine")
