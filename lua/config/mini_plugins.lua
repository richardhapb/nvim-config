-- Mini plugins for specific tasks
local plugins = { 'FormatDicts', 'LatexPreview', 'marp', 'mermaid', 'sqlquery', 'jn_watcher', "executor", "copilot",
  "aligner", "statusline" }

for _, plugin in ipairs(plugins) do
  require('plugin.' .. plugin).setup()
end

vim.pack.add({
  { src = "https://github.com/nvim-mini/mini.nvim",                             name = "mini" },
  { src = "https://github.com/rose-pine/neovim" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/tpope/vim-fugitive",                              name = "fugitive" },
  { src = "https://github.com/christoomey/vim-tmux-navigator",                  name = "tmux-navigator" },
  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "pytest.nvim") },
  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "neospeller.nvim") },
})

-- Some basics plugins

local opts = {
  surround = {},
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
  end,
  completion = {}
}

for name, config in pairs(opts) do
  require('mini.' .. name).setup((function()
    if type(config) == "table" then
      return config
    end

    if type(config) == "function" then
      return config()
    end

    return {}
  end)())
end

require 'nvim-treesitter.configs'.setup({
  ensure_installed = {
    "lua", "bash", "vim", "python", "javascript", "typescript",
    "markdown", "markdown_inline", "html", "css", "json",
    "sql", "gitignore", "dockerfile", "rust", "c", "go",
    "mermaid", "astro", "yaml", "xml", "bash", "toml", "htmldjango"
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

require "gitsigns".setup()
vim.cmd "packadd fugitive"

local fzf = require "fzf-lua"
fzf.setup()

local fzf_pickers = require 'plugin.pickers.docker'

vim.keymap.set("n", "<leader><leader>", fzf.files, { desc = "Find Files" })
vim.keymap.set("n", "<leader>bb", fzf.buffers, { desc = "Find Buffers" })
vim.keymap.set("n", "<leader>fl", fzf.grep, { desc = "Grep" })
vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Live Grep" })
vim.keymap.set("n", "<leader>fd", fzf_pickers.docker_containers, { desc = "Docker containers" })

-- Additional mappings
vim.keymap.set("n", "<leader>fh", fzf.help_tags, { desc = "Help Tags" })
vim.keymap.set("n", "<leader>fk", fzf.keymaps, { desc = "Keymaps" })
vim.keymap.set("n", "<leader>fc", fzf.commands, { desc = "Commands" })
vim.keymap.set("n", "<leader>ft", fzf.colorschemes, { desc = "Colorschemes" })
vim.keymap.set("n", "<leader>fq", fzf.quickfix, { desc = "Quickfix" })
vim.keymap.set("n", "<leader>gf", fzf.git_files, { desc = "Git Files" })
vim.keymap.set("n", "<leader>fr", fzf.registers, { desc = "Registers" })
vim.keymap.set("n", "<leader>fb", fzf.git_branches, { desc = "Git branches" })
vim.keymap.set("n", "<leader>fB", fzf.git_blame, { desc = "Git blame" })


local tn = {
  ["<c-h>"] = "<cmd><C-U>TmuxNavigateLeft<cr>",
  ["<c-j>"] = "<cmd><C-U>TmuxNavigateDown<cr>",
  ["<c-k>"] = "<cmd><C-U>TmuxNavigateUp<cr>",
  ["<c-l>"] = "<cmd><C-U>TmuxNavigateRight<cr>",
  ["<c-\\>"] = "<cmd><C-U>TmuxNavigatePrevious<cr>",
}

for km, direction in pairs(tn) do
  vim.keymap.set("n", km, "<cmd><C-U>TmuxNavigate" .. direction,
    { desc = "TmuxNav navigate " .. direction, silent = true })
end

--- My plugins
--
require 'neospeller'.setup()
require 'pytest'.setup((function()
  local utils = require 'functions.utils'
  return {
    docker = {
      enabled = function()
        return vim.fn.getcwd():find("ddirt") ~= nil or vim.fn.getcwd():find("fundfridge") ~= nil or
            vim.fn.getcwd():find("agora_hedge") ~= nil
      end,
      container = function()
        if vim.fn.getcwd():find("ddirt") == nil and vim.fn.getcwd():find("agora_hedge") == nil and vim.fn.getcwd():find("fundfridge") == nil then return end

        local parent_dir = utils.get_root_cwd_dir()
        return parent_dir .. "-web-1"
      end,
      enable_docker_compose = true,
      docker_compose_service = 'web',
      local_path_prefix = function()
        if vim.fn.getcwd():find("ddirt") or vim.fn.getcwd():find("agora_hedge") then
          return "app"
        elseif vim.fn.getcwd():find("fundfridge") then
          return "fundfridge"
        end

        return ""
      end
    },
    django = {
      enabled = true
    }
  }
end)())

vim.keymap.set({ "x", "n" }, "<leader>S", ":CheckSpell<CR>", { desc = "Check spelling", silent = true })
vim.keymap.set({ "x", "n" }, "<leader>D", ":CheckSpellText<CR>", { desc = "Check spelling", silent = true })
