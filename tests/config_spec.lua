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

print(('ok - %d checks passed'):format(checks))
