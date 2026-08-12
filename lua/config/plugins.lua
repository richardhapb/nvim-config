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
--   diffview                   `:diffsplit` diffs one file against one rev;
--                              no file panel over a commit, no file history
--   gitlab.nvim, octo          review MRs/PRs *in the diff*: `glab`/`gh` in a
--                              terminal cannot comment on a diff line
--   render-markdown            `conceallevel` hides the markers and treesitter
--                              colours them, but neither draws a table border,
--                              a heading background or a code-block frame
--   mini.icons                 filetype icons, and the `nvim-web-devicons` shim
--                              that fzf-lua, diffview and octo all look for
--   neo-tree                   a persistent tree sidebar; netrw is a full-window
--                              buffer listing one directory at a time. Both stay
--                              -- netrw on `-` / `<C-s>`, neo-tree on `<leader>T`
--
-- Deliberately absent, with the builtin that replaces it:
--   undotree             -> `g-` / `g+` / `:earlier 10m` / `:undolist`
--   mini.completion      -> `vim.lsp.completion.enable` (see config/lsp.lua)
--   no-neck-pain         -> `:vsplit` + `:vertical resize`

vim.pack.add {
  -- Colorscheme
  { src = "https://github.com/rose-pine/neovim" },

  -- Tools
  -- Icon provider. The standalone mirror, not the mini.nvim monorepo `main`
  -- pulls: this is the only mini module used here, and the split-out repo
  -- exposes the same `mini.icons` module path.
  { src = "https://github.com/nvim-mini/mini.icons" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/christoomey/vim-tmux-navigator",                  name = "tmux-navigator" },
  { src = 'https://github.com/dmtrKovalenko/fff.nvim' },
  { src = "https://github.com/tpope/vim-fugitive",                              name = "fugitive" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/folke/trouble.nvim" },
  { src = "https://github.com/dlyongemallo/diffview-plus.nvim",                 name = "diffview" },
  -- In-buffer markdown rendering. plugin/pandoc_div.lua and
  -- plugin/mermaid_ascii.lua are written as complements to it: both leave the
  -- source alone and only add virtual text, so the three compose.
  { src = "https://github.com/MeanderingProgrammer/render-markdown.nvim",       name = "render-markdown" },

  -- Review stack. plenary and nui are library deps, not tools in their own
  -- right: gitlab.nvim and octo both need them.
  { src = "https://github.com/nvim-lua/plenary.nvim",                           name = "plenary" },
  { src = "https://github.com/MunifTanjim/nui.nvim",                            name = "nui" },
  -- GitLab MR review (diff, inline comments, approve). Needs the Go binary
  -- built on install -- see the PackChanged autocmd below.
  { src = "https://github.com/harrisoncramer/gitlab.nvim",                      name = "gitlab.nvim" },
  -- GitHub PR review, the octo.nvim counterpart to gitlab.nvim. Auth comes from
  -- the already-authenticated `gh` CLI; pickers reuse fzf-lua.
  { src = "https://github.com/pwntester/octo.nvim",                             name = "octo" },
  -- Tree sidebar. Reuses plenary/nui above; icons come from the mini.icons
  -- devicons mock, so it needs nothing else.
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim",                     name = "neo-tree" },

  -- Mine (local checkouts)
  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "pytest.nvim") },
  { src = vim.fs.joinpath(vim.fn.expand("$HOME"), "plugins", "neospeller.nvim") },
}

-- Builtins that ship with Neovim but are opt-in.
vim.cmd "packadd! termdebug"
vim.cmd "packadd! cfilter"

-- Icons ----------------------------------------------------------------------

-- Must run before fzf-lua, diffview and octo are configured below: each probes
-- for a provider at setup time and caches the answer.
require 'mini.icons'.setup()

-- fzf-lua and render-markdown find mini.icons on their own, but octo's review
-- file panel does a bare `require "nvim-web-devicons"` and diffview looks for
-- the same module. The mock serves that API from mini.icons, so neither needs
-- the extra plugin.
require 'mini.icons'.mock_nvim_web_devicons()

-- My own modules. These are not "plugins hiding Neovim" -- they are Neovim's
-- API used directly, so they stay.
local plugins = {
  "statusline", "aligner", "git_link", "pandoc_div",
  "mermaid_ascii", "heramty", "checkr_mr", "gh_pr",
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
  { "tt", { mode = "diagnostics", win = tr_bottom },                       "Diagnostics (Trouble)" },
  { "tx", { mode = "diagnostics", filter = { buf = 0 }, win = tr_bottom }, "Buffer diagnostics (Trouble)" },
  { "ts", { mode = "symbols", win = tr_right },                            "Symbols (Trouble)" },
  { "tl", { mode = "lsp", focus = false, win = tr_right },                 "LSP definitions / references (Trouble)" },
  { "tL", { mode = "loclist", win = tr_bottom },                           "Location list (Trouble)" },
  { "tQ", { mode = "qflist", win = tr_bottom },                            "Quickfix list (Trouble)" },
}

for _, view in ipairs(trouble_views) do
  local lhs, opts, desc = view[1], view[2], view[3]
  vim.keymap.set("n", "<leader>" .. lhs, function()
    require 'trouble'.toggle(opts)
  end, { silent = true, desc = desc })
end

-- Diffs -----------------------------------------------------------------------

-- On the laptop screen side-by-side leaves ~55 usable columns per pane, so
-- anything long runs off the edge. Below NARROW_COLUMNS use the single-window
-- unified layout (`diff1_inline`): full width *and* full height, git-diff style
-- with deletions as virtual lines. Side-by-side comes back on a monitor.
-- `followwrap` is what stops diff mode from forcing 'nowrap' back on.
vim.opt.diffopt:append("followwrap")

-- Layout modes live in functions/diffview_mode.lua: browsing and MR review
-- disagree about single-window layouts, and the setting is global to diffview.
local diff_view = require "functions.diffview_mode"

require "diffview".setup {
  enhanced_diff_hl = true,
  -- Served by mini.icons through the devicons mock (see the Icons section).
  use_icons = true,
  view = {
    -- winbar_info labels each window with its revision -- needed once panes
    -- stack (or collapse into one) and "left/right" stops telling you which.
    default = { layout = diff_view.layout(), winbar_info = true },
    file_history = { layout = diff_view.layout(), winbar_info = true },
    merge_tool = { layout = "diff3_mixed" },
    cycle_layouts = { default = diff_view.browse_cycle },
    -- Added/deleted files have nothing to compare against; skip the empty pane.
    one_sided_layout = "raw",
    inline = { deletion_highlight = "hanging" },
  },
  file_panel = {
    win_config = { position = "left", width = 28 },
  },
  hooks = {
    -- Reclaim the gutters and wrap, so the diff itself gets the columns.
    diff_buf_win_enter = function(_, winid)
      vim.wo[winid].wrap = true
      vim.wo[winid].linebreak = true
      vim.wo[winid].breakindent = true
      vim.wo[winid].number = false
      vim.wo[winid].relativenumber = false
      vim.wo[winid].signcolumn = "no"
      vim.wo[winid].foldcolumn = "0"
    end,
  },
}

-- Resolve the layout from the current width at open time, not at startup, so
-- plugging into a monitor mid-session picks side-by-side -- and undo whatever an
-- MR review left pinned (see functions/diffview_mode.lua).
local function diffview_open(rev)
  return function()
    diff_view.mode("browse")
    local resolved = (rev and (" " .. rev) or "")
    vim.cmd("DiffviewOpen" .. resolved)
  end
end

vim.keymap.set("n", "<leader>F", diffview_open(), { desc = "Open diff view" })
-- Fed as keys, not run: no <CR> leaves the command line open so a path or
-- `--range` can be appended.
vim.keymap.set("n", "<leader>L", function()
  diff_view.mode("browse")
  vim.api.nvim_feedkeys(":DiffviewFileHistory", "n", false)
end, { desc = "Open file history" })
vim.keymap.set("n", "<leader>H", diffview_open("HEAD^!"), { desc = "Open diff view for last commit" })
vim.keymap.set("n", "<leader>M", function()
  local result = vim.system({ "git", "branch", "-l", "master", "main", "--format", "'%(refname:short)'" }):wait()
  if result.code ~= 0 then
    local err = vim.trim((result.stderr or "Unknown error"))
    vim.notify("Error getitng the main branch: " .. err, vim.log.levels.ERROR)
    return
  end

  local branch = vim.trim(result.stdout)
  if not branch or branch == "" then
    vim.notify("main branch not found", vim.log.levels.ERROR)
    return
  end

  diffview_open(branch .. "..HEAD")()
end, { desc = "Open diff against master/main" })

-- Review: GitLab MRs and GitHub PRs -------------------------------------------

-- GitLab MR review (harrisoncramer/gitlab.nvim).
-- Auth reuses the already-authenticated `glab` token instead of a GITLAB_TOKEN
-- env var: derive the host from origin and ask glab for its stored token.
require("gitlab").setup {
  auth_provider = function()
    local host = vim.env["CHECKR_GL_HOST"]
    if not host then
      vim.notify("Checkr gitlab host not defined -- set the CHECKR_GL_HOST env var", vim.log.levels.ERROR)
    end
    local origin = vim.system({ "git", "remote", "get-url", "origin" }, { text = true }):wait()
    if origin.code == 0 then
      local h = origin.stdout:match("@([^:/]+)") or origin.stdout:match("https?://([^/]+)")
      if h then host = vim.trim(h) end
    end

    -- NOTE: the host flag is `--host`; `-h` is `--help` and prints help text.
    local tok = vim.system({ "glab", "config", "get", "--host", host, "token" }, { text = true }):wait()
    local token = vim.trim(tok.stdout or "")
    if tok.code ~= 0 or token == "" then
      return nil, nil, "no glab token for " .. host .. " (run: glab auth login)"
    end
    return token, "https://" .. host .. "/", nil
  end,
}

-- The reviewer runs DiffviewOpen itself, so it has to pick the layout: its
-- diagnostics and comment placement assume two windows and blow up on the
-- single-window layouts browsing uses. Wrapping `open` covers every entry point
-- -- `glr`, `glc`, `:CheckrMR*` and reviewer.reload() all go through it.
diff_view.pin_reviewer(require("gitlab.reviewer"))

local gitlab = require("gitlab")
-- Entry points: <leader>M (in checkr_mr.lua) picks the repo first; these act on
-- the repo/MR you're already in.
vim.keymap.set("n", "<leader>glr", gitlab.review, { desc = "GitLab: review current MR" })
vim.keymap.set("n", "<leader>glc", gitlab.choose_merge_request, { desc = "GitLab: choose MR to review" })
vim.keymap.set("n", "<leader>gla", gitlab.approve, { desc = "GitLab: approve MR" })
vim.keymap.set("n", "<leader>glA", gitlab.add_assignee, { desc = "GitLab: add assignee" })
-- Inline comments: in the diff, `gln` comments on the cursor line, or use it
-- over a visual selection for a multi-line note; `gls` starts a review thread.
vim.keymap.set({ "n", "v" }, "<leader>gln", gitlab.create_comment, { desc = "GitLab: comment on diff line(s)" })
vim.keymap.set({ "n", "v" }, "<leader>gls", gitlab.create_multiline_comment, { desc = "GitLab: multiline comment" })
vim.keymap.set("n", "<leader>gld", gitlab.toggle_discussions, { desc = "GitLab: toggle discussions panel" })

-- GitHub PR review (pwntester/octo.nvim). Auth comes from the `gh` CLI (personal
-- account). Pickers reuse fzf-lua, matching fzf.register_ui_select() above.
-- `file_panel.icons` is only safe to leave on because of the devicons mock: the
-- review panel renderer does a bare `require "nvim-web-devicons"` per file, and
-- without a provider it errors out on the first one it draws.
require("octo").setup {
  picker = "fzf-lua",
  file_panel = { icons = true },
}

-- Entry points: <leader>P (in gh_pr.lua) picks the repo first; these act on
-- the PR you're already in, mirroring the <leader>gl* GitLab maps. octo's own
-- buffer-local maps cover the rest (e.g. add comment, react, resolve thread).
--
-- `<leader>ghR`, not `ghr`: config/keymaps.lua loads after this file and owns
-- `<leader>ghh` / `<leader>ghr` for gitsigns hunks, so `ghr` here would be
-- silently overwritten.
vim.keymap.set("n", "<leader>ghR", "<cmd>Octo review start<cr>", { desc = "GitHub: start PR review" })
vim.keymap.set("n", "<leader>ghs", "<cmd>Octo review submit<cr>", { desc = "GitHub: submit PR review" })
vim.keymap.set("n", "<leader>ghc", "<cmd>Octo review commit<cr>", { desc = "GitHub: pick review commit" })
vim.keymap.set("n", "<leader>gha", "<cmd>Octo pr checks<cr>", { desc = "GitHub: PR checks" })
vim.keymap.set({ "n", "v" }, "<leader>ghn", "<cmd>Octo comment add<cr>", { desc = "GitHub: comment on diff line(s)" })
vim.keymap.set("n", "<leader>ghd", "<cmd>Octo pr changes<cr>", { desc = "GitHub: toggle changed files" })

-- Explorer -------------------------------------------------------------------

-- Sidebar rooted at cwd. netrw keeps `-` and `<C-s>`, so this gets `<leader>T`:
-- lowercase `<leader>t*` is the trouble.nvim prefix (six maps above).
require "neo-tree".setup {}
vim.keymap.set("n", "<leader>T", "<cmd>Neotree toggle<cr>", { desc = "Toggle Neo-tree" })

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
