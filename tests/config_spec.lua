-- Regression tests for bugs fixed on the `min` branch.
-- Run with:  nvim --headless -l tests/config_spec.lua
-- Exits non-zero on the first failed assertion.
--
-- Every case here is a bug that was live in the config, not a hypothetical.

local cfg = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))
package.path = vim.fs.joinpath(cfg, 'lua', '?.lua') .. ';' .. package.path

-- `nvim -l` does not source init.lua, so load it explicitly: these assertions
-- are about what the real config does at startup.
dofile(vim.fs.joinpath(cfg, 'init.lua'))

local checks = 0
local function eq(got, want, what)
  checks = checks + 1
  if got ~= want then
    io.stderr:write(('not ok - %s\n  got:  %s\n  want: %s\n'):format(what, vim.inspect(got), vim.inspect(want)))
    os.exit(1)
  end
end

-- vim.fn.has() returns 0 or 1, and 0 is TRUTHY in Lua. Every `if vim.fn.has(x)`
-- without `== 1` is therefore always taken. init.lua used to load both
-- macos.lua and linux.lua because of this.
eq(vim.fn.has('0.12.0'), 0, "has('0.12.0') is 0 -- not a feature name")
eq(type(vim.fn.has('nvim-0.12')), 'number', 'has() returns a number, never a boolean')
eq(vim.fn.has('nvim-0.12') == 1, true, "has('nvim-0.12') == 1 is the correct test")

-- `not type(x) == "table"` parses as `(not x) == "table"`, i.e. `false ==
-- "table"`, i.e. always false -- so the gL toggle only ever turned virtual
-- text off. These two lines pin the corrected expression's truth table.
eq(type({ spacing = 4 }) ~= 'table', false, 'gL: virtual_text is a table -> turn off')
eq(type(false) ~= 'table', true, 'gL: virtual_text is off -> turn on')

-- `which` exits non-zero with empty stdout, and "" is truthy, so the old
-- `a or b` one-liner could never reach its python3 fallback.
local py = require('functions.lsp').search_python_path()
eq(type(py) == 'string' and py ~= '', true, 'search_python_path resolves an interpreter')

-- fzf-lua passes opts.cwd; the git_root override used to ignore it and always
-- probe Neovim's cwd, so pickers scoped elsewhere resolved the wrong root.
local fzf = require('fzf-lua')
local here = vim.fn.getcwd()
eq(fzf.path.git_root({ cwd = here }, true), here, 'git_root honours opts.cwd inside a worktree')
eq(fzf.path.git_root({ cwd = '/tmp' }, true), '/tmp', 'git_root falls back to opts.cwd, not nvim cwd')

-- $FZF_DEFAULT_OPTS is inherited from the shell. `--tmux` makes fzf relaunch
-- in a tmux popup, which strands fzf-lua's terminal buffer; `--height` fights
-- fzf-lua's sizing. Both must be stripped, the rest left alone.
local opts = vim.env.FZF_DEFAULT_OPTS or ''
eq(opts:find('%-%-tmux'), nil, '--tmux stripped from FZF_DEFAULT_OPTS')
eq(opts:find('%-%-height'), nil, '--height stripped from FZF_DEFAULT_OPTS')

-- Autocommands without a group stack up another copy every time init.lua is
-- re-sourced (<leader>I), so treesitter.start ran once per source.
local function count(event, group)
  return #vim.api.nvim_get_autocmds({ event = event, group = group })
end
local before = count('FileType', 'TreesitterStart')
dofile(vim.fs.joinpath(cfg, 'init.lua'))
eq(count('FileType', 'TreesitterStart'), before, 'TreesitterStart does not duplicate on re-source')
eq(count('LspProgress', 'LspProgressBar'), 1, 'LspProgressBar does not duplicate on re-source')

-- trouble.nvim keymaps. Two things can go wrong silently: a second `keymap()`
-- with the same lhs overwrites the first without a word, and a typo in `mode`
-- only surfaces as a "Invalid mode" notification the moment the key is pressed.
local trouble_modes = require('trouble.config').modes()
local function n_maps(lhs)
  local hits = 0
  for _, m in ipairs(vim.api.nvim_get_keymap('n')) do
    if m.lhs == lhs then hits = hits + 1 end
  end
  return hits
end

for lhs, mode in pairs({
  [' tt'] = 'diagnostics',
  [' tx'] = 'diagnostics',
  [' ts'] = 'symbols',
  [' tl'] = 'lsp',
  [' tL'] = 'loclist',
  [' tQ'] = 'qflist',
}) do
  eq(n_maps(lhs), 1, ('%s is mapped exactly once'):format(lhs))
  eq(vim.tbl_contains(trouble_modes, mode), true, ('%q is a real trouble mode'):format(mode))
end

-- Review stack (diffview + gitlab.nvim + octo), ported from `main`.
--
-- The `<leader>gh*` namespace is shared: config/keymaps.lua loads *after*
-- config/plugins.lua and maps `<leader>ghh`/`<leader>ghr` to gitsigns, so an
-- octo map on either lhs is overwritten with no warning (that is why review
-- start lives on `<leader>ghR`). Pin one map per lhs, and pin that the two
-- gitsigns maps still point at gitsigns.
local function rhs_of(lhs, mode)
  for _, m in ipairs(vim.api.nvim_get_keymap(mode or 'n')) do
    if m.lhs == lhs then return m.rhs or '<callback>' end
  end
end

for _, lhs in ipairs({
  ' F', ' L', ' H',                              -- diffview
  ' M', ' P', ' mo',                             -- repo/MR/PR pickers
  ' glr', ' glc', ' gla', ' glA', ' gld',        -- gitlab.nvim
  ' ghR', ' ghs', ' ghc', ' gha', ' ghd',        -- octo
}) do
  eq(n_maps(lhs), 1, ('%s is mapped exactly once'):format(lhs))
end

eq(rhs_of(' ghh'), ':Gitsigns preview_hunk<CR>', 'gitsigns keeps <leader>ghh')
eq(rhs_of(' ghr'), ':Gitsigns reset_hunk<CR>', 'gitsigns keeps <leader>ghr')

-- octo's review file panel does a bare `require "nvim-web-devicons"` per file
-- when file_panel.icons is truthy, and diffview looks for the same module.
-- nvim-web-devicons is not installed: mini.icons' mock is what answers, so the
-- two must be pinned together -- icons on with no provider errors on the first
-- file the panel draws.
eq(require('octo.config').values.file_panel.icons, true, 'octo file panel icons are on')
local has_devicons, devicons = pcall(require, 'nvim-web-devicons')
eq(has_devicons, true, 'nvim-web-devicons resolves (via the mini.icons mock)')
eq(type(devicons.get_icon), 'function', 'the mock supplies get_icon, which octo calls')
eq(select(2, devicons.get_icon('init.lua', 'lua', { default = true })) ~= nil, true,
  'get_icon returns a highlight group, not just an icon')

-- diffview's layout is chosen from the window width. Both branches of
-- diff_layout() must name layouts diffview actually accepts -- a typo here only
-- surfaces as an error when the view opens.
local dv = require('diffview.config').get_config()
eq(dv.use_icons, true, 'diffview icons on (mini.icons provides them)')
eq(vim.tbl_contains({ 'diff1_inline', 'diff2_horizontal' }, dv.view.default.layout),
  true, 'default layout is one of the two width-dependent layouts')
eq(dv.view.file_history.layout, dv.view.default.layout, 'file history follows the default layout')
eq(vim.tbl_contains(vim.opt.diffopt:get(), 'followwrap'), true,
  "followwrap is set, or diff mode forces 'nowrap' back on")

-- The reviewers are driven from these two modules; their user commands are the
-- entry points the `tmux-mr` script calls, so a rename breaks it silently.
for _, cmd in ipairs({ 'CheckrMR', 'CheckrMROpen', 'CheckrMRReview', 'GhPR', 'GhPROpen', 'GhPRReview' }) do
  eq(vim.fn.exists(':' .. cmd), 2, (':%s is defined'):format(cmd))
end

-- URL routing: <leader>mo sends a GitHub URL to octo and everything else to
-- gitlab.nvim, off this one predicate.
local gh = require('plugin.gh_pr')
eq(gh.is_github('github.com'), true, 'github.com is GitHub')
eq(gh.is_github('gitlab.checkrhq.net'), false, 'the Checkr GitLab host is not GitHub')
eq(gh.is_github(nil), false, 'a missing host is not GitHub')

-- Icons. Each consumer probes for a provider and caches the answer, so a
-- mini.icons.setup() that ran too late would leave them silently icon-less with
-- no error to show for it. render-markdown's probe additionally requires the
-- `MiniIcons` global, which only setup() sets -- `require` alone is not enough.
eq(require('render-markdown.lib.icons').name(), 'mini.icons',
  'render-markdown resolved mini.icons as its provider')
eq(type(_G.MiniIcons), 'table', 'mini.icons.setup() ran (render-markdown checks this global)')
eq(require('fzf-lua.devicons').get_devicon('init.lua') ~= nil, true,
  'fzf-lua has an icon for init.lua')

-- neo-tree lives alongside netrw rather than replacing it, so all three lhs must
-- survive: `<leader>t*` is trouble's prefix, which is why the toggle is `<leader>T`.
eq(n_maps(' T'), 1, '<leader>T toggles neo-tree exactly once')
eq(rhs_of('-'), '<Cmd>Explore<CR>', 'netrw keeps `-`')
eq(rhs_of('<C-S>'), '<Cmd>Explore .<CR>', 'netrw keeps <C-s>')
eq(vim.fn.exists(':Neotree'), 2, ':Neotree is defined')

-- Markdown rendering: render-markdown.nvim + plugin/pandoc_div + mermaid_ascii.
--
-- render-markdown is never `setup()` here. Its own plugin/render-markdown.lua
-- does that from `vim.g.render_markdown_config`, so the config only lists the
-- pack spec -- and if that entry point ever changes, rendering stops with no
-- error at all. Pin that it came up.
eq(require('render-markdown.state').enabled, true, 'render-markdown enabled without an explicit setup()')

-- The three renderers must not fight over extmarks: each owns its own
-- namespace, and pandoc_div's conceal needs `conceallevel` >= 2, which
-- render-markdown's window options are what normally supply.
local md = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(md, 0, -1, false, {
  '# Heading', '', '::: note', 'A pandoc fenced div.', ':::', '',
  '```mermaid', 'graph LR', '  A[Activity] --> B{automate?}', '```',
})
vim.api.nvim_win_set_buf(0, md)
vim.bo[md].filetype = 'markdown'
local source = vim.api.nvim_buf_get_lines(md, 0, -1, false)

eq(vim.wo.conceallevel >= 2, true, 'a markdown window conceals (pandoc_div needs it)')

local namespaces = vim.api.nvim_get_namespaces()
for _, ns in ipairs({ 'render-markdown.nvim', 'pandoc_div', 'mermaid_ascii' }) do
  eq(type(namespaces[ns]), 'number', ('%s owns a namespace of its own'):format(ns))
end

-- Both of mine decorate rather than rewrite -- that is what lets them compose
-- with render-markdown, which owns the same lines. A renderer that edited the
-- buffer would corrupt the source on every keystroke.
vim.cmd('PandocDivRender')
eq(#vim.api.nvim_buf_get_extmarks(md, namespaces['pandoc_div'], 0, -1, {}) > 0,
  true, 'pandoc_div marks up a fenced div')
eq(vim.deep_equal(vim.api.nvim_buf_get_lines(md, 0, -1, false), source),
  true, 'rendering leaves the markdown source untouched')

for _, cmd in ipairs({ 'MermaidAsciiRender', 'MermaidAsciiToggle', 'MermaidAsciiFloat', 'PandocDivRender' }) do
  eq(vim.fn.exists(':' .. cmd), 2, (':%s is defined'):format(cmd))
end

-- `<leader>e` in a markdown buffer: the mermaid diagram when the cursor is in a
-- block, the diagnostic float everywhere else. The map has to be buffer-local to
-- shadow the global one functions/lsp.lua sets on LspAttach, and the fall-through
-- has to stay -- markdown has real diagnostics here (harper_ls, ltex both attach).
local mermaid = require('plugin.mermaid_ascii')
local function buf_maps(lhs, buf)
  local hits = 0
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf or 0, 'n')) do
    if m.lhs == lhs then hits = hits + 1 end
  end
  return hits
end
eq(buf_maps(' e', md), 1, '<leader>e is mapped buffer-locally in markdown')

vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- '# Heading', outside any block
eq(mermaid.float(), false, 'outside a mermaid block float() declines, so diagnostics answer')

-- Rendering needs the `mermaid-ascii` binary and is async, so wait on it. Without
-- the binary the module is documented to no-op; say so rather than failing.
local function open_floats()
  local wins = {}
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative ~= '' then wins[#wins + 1] = w end
  end
  return wins
end

if vim.fn.executable('mermaid-ascii') == 1 then
  vim.api.nvim_win_set_cursor(0, { 8, 0 }) -- 'graph LR', inside the block
  eq(mermaid.float(), true, 'inside a mermaid block float() takes the key')

  -- float() returns true as soon as it has something in flight, so wait for the
  -- window rather than assuming it is already up.
  eq(vim.wait(15000, function() return #open_floats() > 0 end, 100), true,
    'the diagram float opens (cold cache renders, then shows)')

  local win = open_floats()[1]
  local shown = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
  eq(table.concat(shown, '\n'):find('Activity') ~= nil, true, 'the float shows the rendered diagram')
  -- Soft wrap would fold the box-drawing lines and make the diagram unreadable.
  eq(vim.wo[win].wrap, false, 'the float does not wrap')
  -- Anchored to the editor, not the cursor: cursor-relative caps the height at
  -- the space on one side of the cursor, which is half a screen mid-file.
  local win_cfg = vim.api.nvim_win_get_config(win)
  eq(win_cfg.relative, 'editor', 'the float is anchored to the editor, not the cursor')
  eq(win_cfg.anchor, 'NW', 'the float starts at the top-left')
  -- focus_id: a second press focuses the existing float instead of stacking one.
  mermaid.float()
  eq(#open_floats(), 1, 'a second float() reuses the window instead of stacking')
  vim.api.nvim_win_close(win, true)

  -- A diagram under the cap is drawn whole, with no hint row bolted on.
  local ns_mermaid = namespaces['mermaid_ascii']
  local small = vim.api.nvim_buf_get_extmarks(md, ns_mermaid, 0, -1, { details = true })[1]
  eq(small ~= nil, true, 'the short diagram renders inline')
  local small_rows = small[4].virt_lines
  eq(#small_rows < 10, true, 'a diagram under the cap is not truncated')
  eq(small_rows[#small_rows][1][2], 'MermaidAscii', 'no hint row on an untruncated diagram')

  -- Over the cap it becomes a teaser. These get tall fast -- this six-node
  -- `graph TD` renders 55 rows, which would bury the rest of the file. The cap
  -- counts the hint row, so the footprint is never more than max_lines.
  local tall = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(tall, 0, -1, false, {
    '```mermaid', 'graph TD', '  A[Start] --> B[Step one]', '  B --> C[Step two]',
    '  C --> D[Step three]', '  D --> E[Step four]', '  E --> F[Done]', '```',
  })
  vim.api.nvim_win_set_buf(0, tall)
  vim.bo[tall].filetype = 'markdown'
  eq(vim.wait(20000, function()
    return #vim.api.nvim_buf_get_extmarks(tall, ns_mermaid, 0, -1, {}) > 0
  end, 100), true, 'the tall diagram renders inline')

  local rows = vim.api.nvim_buf_get_extmarks(tall, ns_mermaid, 0, -1, { details = true })[1][4].virt_lines
  eq(#rows, 10, 'inline preview is capped at 10 rows, hint row included')
  eq(rows[#rows][1][2], 'MermaidAsciiTruncated', 'the last row is the truncation hint')
  eq(rows[#rows][1][1]:find('more rows') ~= nil, true, 'the hint says how many rows are hidden')

  -- The cap is on the inline preview only -- the float is why truncating is safe.
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  mermaid.float()
  eq(vim.wait(15000, function() return #open_floats() > 0 end, 100), true,
    'the tall diagram still floats')
  local full = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(open_floats()[1]), 0, -1, false)
  eq(#full > #rows, true, 'the float shows more rows than the capped inline preview')
else
  print('# skipped: mermaid-ascii binary not installed, float and cap unchecked')
end

-- gitlab.nvim's reviewer indexes `cur_layout.a` directly, so a one-window layout
-- kills it: opening an added file in an MR diff gave it a `diff1_raw` layout
-- (from `one_sided_layout = "raw"`) and every DiffviewDiffBufWinEnter failed with
-- "attempt to index field 'a' (a nil value)". Review mode keeps two windows.
local diff_view = require('functions.diffview_mode')
local dv_view = require('diffview.config').get_config().view

diff_view.mode('review')
eq(dv_view.one_sided_layout, 'default', 'review keeps the placeholder pane for added/deleted files')
eq(dv_view.default.layout:sub(1, 5), 'diff2', 'review opens a two-window layout')
for _, layout in ipairs(dv_view.cycle_layouts.default) do
  eq(layout:sub(1, 5), 'diff2', 'g<C-x> cannot cycle a review down to one window: ' .. layout)
end

-- Browsing is what wants the single-window treatments, and it has to set them
-- back: diffview's layout config is global, so whoever opens last owns it.
diff_view.mode('browse')
eq(dv_view.one_sided_layout, 'raw', 'browsing drops the empty pane again')
eq(vim.tbl_contains(dv_view.cycle_layouts.default, 'diff1_inline'), true, 'browsing can cycle to inline')

-- reviewer.open() is the choke point: `glr`, `glc`, `:CheckrMRReview` and
-- reviewer.reload() all reach diffview through it.
local fake_reviewer = { open = function() return dv_view.one_sided_layout end }
diff_view.pin_reviewer(fake_reviewer)
eq(fake_reviewer.open(), 'default', 'reviewer.open() switches to review mode before opening diffview')

local pinned = fake_reviewer.open
diff_view.pin_reviewer(fake_reviewer)
eq(fake_reviewer.open == pinned, true, 'pinning twice is a no-op -- re-sourcing must not stack wrappers')

-- Layouts are built one file at a time, so browsing a diff in another tab while
-- a review is open would put the review's next file back on a browsing layout.
fake_reviewer.tabid = vim.api.nvim_get_current_tabpage()
diff_view.mode('browse')
vim.api.nvim_exec_autocmds('TabEnter', {})
eq(dv_view.one_sided_layout, 'default', 'entering the review tab re-pins review mode')

fake_reviewer.tabid = nil
diff_view.mode('browse')
vim.api.nvim_exec_autocmds('TabEnter', {})
eq(dv_view.one_sided_layout, 'raw', 'other tabs are left in browse mode')

eq(require('gitlab.reviewer').__diffview_mode_pinned, true, 'the real reviewer is pinned at startup')

print(('ok - %d checks passed'):format(checks))
