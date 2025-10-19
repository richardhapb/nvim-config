vim.pack.add({
  { src = "https://github.com/nvim-mini/mini.nvim",                             name = "mini" },
  { src = "https://github.com/rose-pine/neovim" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/tpope/vim-fugitive",                              name = "fugitive" },
  { src = "https://github.com/christoomey/vim-tmux-navigator",                  name = "tmux-navigator" },
  { src = "https://github.com/jiaoshijie/undotree" },
  { src = "https://github.com/GCBallesteros/jupytext.nvim",                     name = "jupytext" },
  { src = "https://github.com/Vigemus/iron.nvim",                               name = "iron" },
  { src = "https://github.com/3rd/image.nvim",                                  name = "image" },

  -- DAP plugins
  { src = "https://github.com/mfussenegger/nvim-dap" },
  { src = "https://github.com/mfussenegger/nvim-dap-python" },
  { src = "https://github.com/rcarriga/nvim-dap-ui" },
  { src = "https://github.com/nvim-neotest/nvim-nio" },
  { src = "https://github.com/jbyuki/one-small-step-for-vimkind" },
  { src = "https://github.com/theHamsta/nvim-dap-virtual-text" },

  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "pytest.nvim") },
  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "neospeller.nvim") },
})

vim.cmd "packadd! termdebug"

-- Mini plugins for specific tasks
local plugins = { 'FormatDicts', 'LatexPreview', 'marp', 'mermaid', 'sqlquery', 'jn_watcher', "executor", "copilot",
  "aligner", "statusline", "jupyter", "dap" }

for _, plugin in ipairs(plugins) do
  require('plugin.' .. plugin).setup()
end

-- Some basics plugins

local opts = {
  surround = {},
  icons = {},
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
    "sql", "gitignore", "dockerfile", "rust", "c", "go", "make",
    "mermaid", "astro", "yaml", "xml", "bash", "toml", "htmldjango",
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

local fzf_docker = require 'plugin.pickers.docker'
local fzf_git = require 'plugin.pickers.git'

vim.keymap.set("n", "<leader><leader>", fzf.files, { desc = "Find Files" })
vim.keymap.set("n", "<leader>bb", fzf.buffers, { desc = "Find Buffers" })
vim.keymap.set("n", "<leader>fl", fzf.grep, { desc = "Grep" })
vim.keymap.set("n", "<leader>ff", fzf.builtin, { desc = "FzfLua builtins" })
vim.keymap.set("n", "<leader>fm", fzf.manpages, { desc = "Man pages" })
vim.keymap.set("n", "<leader>fs", fzf.lsp_document_symbols, { desc = "LSP doc symbols" })
vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Live Grep" })
vim.keymap.set("n", "<leader>fd", fzf_docker.docker_containers, { desc = "Docker containers" })
vim.keymap.set("n", "<leader>fw", fzf_git.worktrees, { desc = "Git Worktrees" })


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

require "undotree".setup()
vim.keymap.set('n', '<leader>u', require('undotree').toggle, { noremap = true, silent = true })


--- JUPYTER NOTEBOOKS

require 'jupytext'.setup()
require("image").setup({
  backend = "sixel",
  max_width = 100,                          -- tweak to preference
  max_height = 12,                          -- ^
  max_height_window_percentage = math.huge, -- this is necessary for a good experience
  max_width_window_percentage = math.huge,
  window_overlap_clear_enabled = true,
  window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
})

require 'iron'.setup {
  config = {
    -- Whether a repl should be discarded or not
    scratch_repl = true,
    -- Your repl definitions come here

    repl_definition = {
      python = require("iron.fts.python").ipython,
      scala = require("iron.fts.scala").scala,
    },
    -- How the repl window will be displayed
    -- See below for more information
    repl_open_cmd = require "iron.view".split.vertical.botright(100)
  },
  -- If the highliht is on, you can change how it looks
  -- For the available options, check nvim_set_hl
  highlight = {
    italic = true,
  },
  ignore_blank_lines = true, -- ignore blank lines when sending visual select lines
}


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
