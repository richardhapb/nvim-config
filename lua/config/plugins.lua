-- Minimal plugin set.
--
-- The rule for this branch: a plugin earns its place only if Neovim has no
-- builtin that does the job. Everything else was cut so the builtin shows
-- through -- see doc/minimal.md for what replaced what.
--
--   treesitter (+textobjects)  no builtin parser-based highlighting/textobjects
--   fzf-lua                    file picker + live grep, the two used daily
--   tmux-navigator             needs the tmux side to cooperate
--   rose-pine                  cosmetic only, hides nothing
--   fff.nvim                   frecency ranking `:find` has no answer for
--   fugitive, gitsigns         staging and hunk ops without leaving the buffer
--   trouble                    diagnostics grouped, folded and live-refreshed;
--                              the quickfix list is flat and only a snapshot
--
-- Deliberately absent, with the builtin that replaces it:
--   neo-tree             -> netrw (`-`, `<C-s>`), `:find`, fzf-lua files
--   diffview             -> `git diff`, `git log -p`, `:Gd`
--   octo, gitlab.nvim    -> `gh pr` / `glab mr` in a terminal
--   undotree             -> `g-` / `g+` / `:earlier 10m` / `:undolist`
--   mini.completion      -> `vim.lsp.completion.enable` (see config/lsp.lua)
--   mini.icons           -> nothing; fzf-lua degrades to no icons
--   render-markdown      -> `conceallevel`, treesitter markdown highlights
--   no-neck-pain         -> `:vsplit` + `:vertical resize`

vim.pack.add {
  -- Colorscheme
  { src = "https://github.com/rose-pine/neovim" },

  -- Tools
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/christoomey/vim-tmux-navigator",                  name = "tmux-navigator" },
  { src = 'https://github.com/dmtrKovalenko/fff.nvim' },
  { src = "https://github.com/tpope/vim-fugitive",                              name = "fugitive" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/folke/trouble.nvim" },

  -- Mine (local checkouts)
  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "pytest.nvim") },
  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "neospeller.nvim") },
}

-- Builtins that ship with Neovim but are opt-in.
vim.cmd "packadd! termdebug"
vim.cmd "packadd! cfilter"

-- My own modules. These are not "plugins hiding Neovim" -- they are Neovim's
-- API used directly, so they stay.
local plugins = {
  "statusline", "aligner", "git_link", "pandoc_div",
  "mermaid_ascii", "heramty",
}

for _, plugin in ipairs(plugins) do
  require('plugin.' .. plugin).setup()
end

--- fff ------

vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == 'fff.nvim' and (kind == 'install' or kind == 'update') then
      if not ev.data.active then vim.cmd.packadd('fff.nvim') end
      require('fff.download').download_or_build_binary()
    end
    if name == 'gitlab.nvim' and (kind == 'install' or kind == 'update') then
      if not ev.data.active then vim.cmd.packadd('gitlab.nvim') end
      -- Compile the Go server gitlab.nvim talks to.
      require('gitlab.server').build(true)
    end
  end,
})

vim.g.fff = {
  lazy_sync = true,
  debug = { enabled = false, show_scores = true },
}


-- Treesitter ------------------------------------------------------------------

-- On nvim-treesitter `main`, `config.setup` only accepts `install_dir`.
-- Highlighting is started by the FileType autocmd in `config.autocommands`;
-- indent and textobjects are wired up manually below.

-- Indent is experimental upstream, so keep it off for the common offenders.
local indent_disabled = { python = true, yaml = true, markdown = true }

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("TreesitterIndent", { clear = true }),
  callback = function(args)
    if indent_disabled[args.match] then
      return
    end
    local lang = vim.treesitter.language.get_lang(args.match) or args.match
    local ok, added = pcall(vim.treesitter.language.add, lang)
    if not (ok and added) then
      return
    end
    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
})

require "nvim-treesitter-textobjects".setup {
  select = {
    lookahead = true,
  }
}

local textobjects = {
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
  ["a/"] = "@statement.outer",
}

for lhs, query in pairs(textobjects) do
  vim.keymap.set({ "x", "o" }, lhs, function()
    require "nvim-treesitter-textobjects.select".select_textobject(query, "textobjects")
  end, { desc = "Select " .. query })
end

-- Picker ----------------------------------------------------------------------

-- The one plugin kept that a builtin *could* cover (`:find`, `:grep`, `:b`).
-- It stays because file picking and live grep are the two things used dozens of
-- times a day. The builtins live on their own keys right next to it (see
-- config/keymaps.lua) so both stay in the fingers.

-- $FZF_DEFAULT_OPTS (set in ~/.zprofile) is written for fzf in a shell, and two
-- of its flags break fzf-lua, which runs fzf *inside* a Neovim terminal buffer:
--
--   --tmux    fzf relaunches itself in a tmux popup, so keystrokes go to the
--             popup while the terminal buffer renders stale and accepts no
--             input -- it looks exactly like a freeze, and only inside tmux.
--   --height  fights fzf-lua for control of the window size.
--
-- fzf-lua forwards the variable verbatim (it only strips `--preview-window`,
-- see fzf.lua), so strip these two here. Only this nvim process is affected;
-- a shell started from nvim re-reads the profile and gets the full value.
if vim.env.FZF_DEFAULT_OPTS then
  vim.env.FZF_DEFAULT_OPTS = vim.env.FZF_DEFAULT_OPTS
      :gsub("%-%-tmux[=%s]+%S+", "")
      :gsub("%-%-height[=%s]+%S+", "")
end

local fzf = require "fzf-lua"

fzf.setup {
  "telescope", -- Allows scroll with C-d and C-u
  keymap = {
    fzf = {
      ["ctrl-q"] = "select-all+accept", -- Send to quickfix
    },
  },
}

-- Route every `vim.ui.select` through fzf so `vim.lsp.buf.code_action` and
-- friends get a fuzzy list instead of the builtin numbered prompt.
fzf.register_ui_select()

--  files auto-completion with fzf
vim.keymap.set({ "n", "v", "i" }, "<C-x><C-f>",
  function() fzf.complete_path() end,
  { silent = true, desc = "Fuzzy complete path" })

-- Handle the case when it is not in a worktree, which occurres in bare repos.
-- git rev-parse --show-toplevel must be executed in a worktree, so probe first
-- and fall back to the directory we were asked about.
--
-- fzf-lua passes `opts.cwd`, and the probe used to ignore it -- it always ran
-- in Neovim's cwd and fell back to `vim.fn.getcwd()`. Any picker scoped to
-- another directory (`files({ cwd = ... })`, the git providers) could then get
-- the wrong root, or be told "not a worktree" while its own cwd was one.
local git_root = fzf.path.git_root
fzf.path.git_root = function(opts, noerr)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()
  local result = vim.system({ "git", "-C", cwd, "rev-parse", "--show-toplevel" }):wait()

  if result.code ~= 0 then
    -- Fallback
    return cwd
  end

  return git_root(opts, noerr)
end

local fff = require 'fff'
local fzf_docker = require 'plugin.pickers.docker'
local fzf_git = require 'plugin.pickers.git'

vim.keymap.set('n', '<leader><leader>', fff.find_files, { desc = 'FFFind files' })
vim.keymap.set('n', '<leader>fg', fff.live_grep, { desc = 'FFFind Live Grep' })
vim.keymap.set('n', '<leader>G', fff.refresh_git_status, { desc = 'FFFind Refresh git' })
vim.keymap.set('n', '<leader>R', fff.scan_files, { desc = 'FFFind force re-scan files' })

vim.keymap.set("n", "<localleader><localleader>", fzf.buffers, { desc = "Find Buffers" })
vim.keymap.set("n", "<leader>fo", function() fzf.oldfiles({ cwd_only = true }) end,
  { desc = "Recent files (cwd)" })
vim.keymap.set("n", "<leader>fO", fzf.oldfiles, { desc = "Recent files (global)" })
vim.keymap.set("n", "<leader>fl", fzf.grep, { desc = "Grep" })
vim.keymap.set("n", "<leader>ff", fzf.builtin, { desc = "FzfLua builtins" })

vim.keymap.set("n", "<leader>fm", fzf.manpages, { desc = "Man pages" })
vim.keymap.set("n", "<leader>fs", fzf.lsp_document_symbols, { desc = "LSP doc symbols" })
vim.keymap.set("n", "<leader>fw", fzf.git_worktrees, { desc = "Git Worktrees" })
vim.keymap.set("n", "<leader>fd", fzf_docker.docker_containers, { desc = "Docker containers" })
vim.keymap.set("n", "<leader>fi", fzf_git.git_branches_diff, { desc = "Git branches diff" })

vim.keymap.set("n", "<leader>fh", fzf.help_tags, { desc = "Help Tags" })
vim.keymap.set("n", "<leader>fk", fzf.keymaps, { desc = "Keymaps" })
vim.keymap.set("n", "<leader>fc", fzf.commands, { desc = "Commands" })
vim.keymap.set("n", "<leader>ft", fzf.colorschemes, { desc = "Colorschemes" })
vim.keymap.set("n", "<leader>fq", fzf.quickfix, { desc = "Quickfix" })
vim.keymap.set("n", "<leader>gf", fzf.git_files, { desc = "Git Files" })
vim.keymap.set("n", "<leader>fr", fzf.registers, { desc = "Registers" })
vim.keymap.set("n", "<leader>fb", function()
  fzf.git_branches({
    -- Clean list: just the branch name (current marked with "* "), no trailing
    -- commit subject. The log lives in the preview.
    -- Note: fzf-lua's switch action parses "<indent>[*] <branch>", so
    -- non-current branches need the two-space indent, and remote refs must
    -- keep the "remotes/" prefix for it to strip when switching.
    cmd = "git branch --all --color "
        .. "--sort=-committerdate --sort=refname:rstrip=-2 --sort=-HEAD "
        .. "--format='%(if)%(HEAD)%(then)%(color:yellow)* %(else)  %(end)"
        .. "%(color:green)%(if:equals=refs/remotes)%(refname:rstrip=-2)"
        .. "%(then)%(refname:lstrip=1)%(else)%(refname:short)%(end)%(color:reset)'",
  })
end, { desc = "Git branches" })
vim.keymap.set("n", "<leader>fB", fzf.git_blame, { desc = "Git blame" })

-- Misc ------------------------------------------------------------------------

local tn = {
  ["<c-h>"] = "Left",
  ["<c-j>"] = "Down",
  ["<c-k>"] = "Up",
  ["<c-l>"] = "Right",
  ["<c-\\>"] = "Previous",
}

for km, direction in pairs(tn) do
  vim.keymap.set("n", km, "<cmd><C-U>TmuxNavigate" .. direction .. "<cr>",
    { desc = "TmuxNav navigate " .. direction, silent = true })
end

-- Trouble ---------------------------------------------------------------------

require 'trouble'.setup()

-- The `<leader>t` prefix is free: the only other `<leader>tl`/`<leader>td` live
-- in plugin/mermaid.lua, buffer-local to its diagram buffer, and that module is
-- not in the loaded list above. Everything else here is a fresh lhs.
--
-- Window shapes: lists go in a bottom split, tree-shaped views on the right.
local tr_bottom = { type = "split", position = "bottom", size = { height = 20 } }
local tr_right = { type = "split", position = "right", size = { width = 80 } }

local trouble_views = {
  { "tt", { mode = "diagnostics", win = tr_bottom },                    "Diagnostics (Trouble)" },
  { "tx", { mode = "diagnostics", filter = { buf = 0 }, win = tr_bottom }, "Buffer diagnostics (Trouble)" },
  { "ts", { mode = "symbols", win = tr_right },                         "Symbols (Trouble)" },
  { "tl", { mode = "lsp", focus = false, win = tr_right },              "LSP definitions / references (Trouble)" },
  { "tL", { mode = "loclist", win = tr_bottom },                        "Location list (Trouble)" },
  { "tQ", { mode = "qflist", win = tr_bottom },                         "Quickfix list (Trouble)" },
}

for _, view in ipairs(trouble_views) do
  local lhs, opts, desc = view[1], view[2], view[3]
  vim.keymap.set("n", "<leader>" .. lhs, function()
    require 'trouble'.toggle(opts)
  end, { silent = true, desc = desc })
end

--- My plugins ----------------------------------------------------------------

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
