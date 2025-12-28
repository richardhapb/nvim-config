vim.pack.add {
  -- Colorscheme
  { src = "https://github.com/rose-pine/neovim" },

  -- Tools
  { src = "https://github.com/nvim-mini/mini.nvim",                             name = "mini" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/tpope/vim-fugitive",                              name = "fugitive" },
  { src = "https://github.com/christoomey/vim-tmux-navigator",                  name = "tmux-navigator" },
  { src = "https://github.com/jiaoshijie/undotree" },
  { src = "https://github.com/shortcuts/no-neck-pain.nvim" },

  -- Jupyter-Notebooks
  { src = "https://github.com/jpalardy/vim-slime.git",                          name = "slime" },

  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "pytest.nvim") },
  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "neospeller.nvim") },
}

-- Builtins
vim.cmd "packadd! termdebug"
vim.cmd "packadd! cfilter"

-- Mini plugins for specific tasks
local plugins = { 'FormatDicts', 'LatexPreview', 'sqlquery', 'jn_watcher', "executor",
  "aligner", "statusline", "jupyter", "fstring" }

for _, plugin in ipairs(plugins) do
  require('plugin.' .. plugin).setup()
end

-- Some basics plugins

local opts = {
  surround = {},
  icons = {},
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


-- Monkey patch the float `info` window, because is displayed behind the dmenu.
local mini_completion = require 'mini.completion'
local _win_info = mini_completion.info_window_options
mini_completion.info_window_options = function()
  local info_opts = _win_info()
  return vim.tbl_deep_extend('force', info_opts, { zindex = 1000 })
end

-- Treesitter

require 'nvim-treesitter.configs'.setup {
  ensure_installed = {
    "lua", "bash", "vim", "python", "javascript", "typescript",
    "markdown", "markdown_inline", "html", "css", "json",
    "sql", "gitignore", "dockerfile", "rust", "c", "go", "make",
    "mermaid", "astro", "yaml", "xml", "bash", "toml", "htmldjango",
    "latex"
  },
  highlight = {
    enable = true,
  },
  indent = {
    enable = true,
    disable = { "python", "yaml", "markdown" }, -- common offenders
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


-- Git

require "gitsigns".setup()
vim.cmd "packadd fugitive"

-- Picker

local fzf = require "fzf-lua"

fzf.setup {
  "telescope", -- Allows scroll with C-d and C-u
  keymap = {
    fzf = {
      ["ctrl-q"] = "select-all+accept", -- Send to quickfix
    },
  },
}

local fzf_files = {
  fd_opts = [[--color=never --type f --type l --exclude .git --exclude .venv]],
  fzf_opts = {
    -- no reverse view
    ["--layout"] = "default",
  },
}

--  files auto-completion with fzf
vim.keymap.set({ "n", "v", "i" }, "<C-x><C-f>",
  function() fzf.complete_path() end,
  { silent = true, desc = "Fuzzy complete path" })

-- Handle the case when it is not in a worktree, which occurres in bare repos.
-- git rev-parse --show-toplevel must be executed in a worktree. As a fallback
-- I use vim cwd, that is the most common case.
local git_root = fzf.path.git_root
fzf.path.git_root = function(args, noerr)
  local result = vim.system({ "git", "rev-parse", "--show-toplevel" }):wait()

  if result.code ~= 0 then
    -- Fallback
    return vim.fn.getcwd()
  end

  return git_root(args, noerr)
end

local fzf_docker = require 'plugin.pickers.docker'

vim.keymap.set("n", "<leader><leader>", function() fzf.files(fzf_files) end, { desc = "Find Files" })
vim.keymap.set("n", "<localleader><localleader>", fzf.buffers, { desc = "Find Buffers" })
vim.keymap.set("n", "<leader>fl", fzf.grep, { desc = "Grep" })
vim.keymap.set("n", "<leader>ff", fzf.builtin, { desc = "FzfLua builtins" })
vim.keymap.set("n", "<leader>fm", fzf.manpages, { desc = "Man pages" })
vim.keymap.set("n", "<leader>fs", fzf.lsp_document_symbols, { desc = "LSP doc symbols" })
vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Live Grep" })
vim.keymap.set("n", "<leader>fd", fzf_docker.docker_containers, { desc = "Docker containers" })
vim.keymap.set("n", "<leader>fw", fzf.git_worktrees, { desc = "Git Worktrees" })


vim.keymap.set("n", "<leader>fh", fzf.help_tags, { desc = "Help Tags" })
vim.keymap.set("n", "<leader>fk", fzf.keymaps, { desc = "Keymaps" })
vim.keymap.set("n", "<leader>fc", fzf.commands, { desc = "Commands" })
vim.keymap.set("n", "<leader>ft", fzf.colorschemes, { desc = "Colorschemes" })
vim.keymap.set("n", "<leader>fq", fzf.quickfix, { desc = "Quickfix" })
vim.keymap.set("n", "<leader>gf", fzf.git_files, { desc = "Git Files" })
vim.keymap.set("n", "<leader>fr", fzf.registers, { desc = "Registers" })
vim.keymap.set("n", "<leader>fb", fzf.git_branches, { desc = "Git branches" })
vim.keymap.set("n", "<leader>fB", fzf.git_blame, { desc = "Git blame" })

-- Misc

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

vim.keymap.set("n", "<localleader>N", ":NoNeckPain<CR>", { silent = true, noremap = true })

require "undotree".setup()
vim.keymap.set('n', '<leader>u', require('undotree').toggle, { noremap = true, silent = true })

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

vim.keymap.set("n", "<leader>O", ":PytestOutput<CR>", { silent = true })

vim.keymap.set({ "x", "n" }, "<leader>S", ":CheckSpell<CR>", { desc = "Check spelling", silent = true })
vim.keymap.set({ "x", "n" }, "<leader>D", ":CheckSpellText<CR>", { desc = "Check spelling", silent = true })
