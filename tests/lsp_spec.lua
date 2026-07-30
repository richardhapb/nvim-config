-- Unit tests for the pure helpers in functions/lsp.
-- Run with:  timeout 30 nvim --headless -l tests/lsp_spec.lua
-- Exits non-zero on the first failed assertion.
--
-- NOTE the `timeout`: the bug this file guards against is an *infinite loop*,
-- not a crash. `_search_upward` used to recurse via a Lua tail call, so a
-- non-terminating walk never blew the stack -- it just froze Neovim. If this
-- suite ever hangs instead of failing, that regression is back.

local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local config = vim.fs.dirname(here)
package.path = vim.fs.joinpath(config, 'lua', '?.lua') .. ';' .. package.path

local lsp = require('functions.lsp')

local checks = 0
local function eq(got, want, what)
  checks = checks + 1
  if not vim.deep_equal(got, want) then
    io.stderr:write(('FAIL %s\n  want: %s\n  got:  %s\n')
      :format(what, vim.inspect(want), vim.inspect(got)))
    os.exit(1)
  end
end

-- ── fixture ──────────────────────────────────────────────────────────────────
-- tmp/
--   project/
--     Gemfile
--     lib/deep/app.rb
--   loose/lib/gem.rb        (no marker anywhere up to /)

local tmp = vim.fn.tempname()
local project = vim.fs.joinpath(tmp, 'project')
local deep = vim.fs.joinpath(project, 'lib', 'deep')
local loose = vim.fs.joinpath(tmp, 'loose', 'lib')

vim.fn.mkdir(deep, 'p')
vim.fn.mkdir(loose, 'p')
vim.fn.writefile({}, vim.fs.joinpath(project, 'Gemfile'))
vim.fn.writefile({}, vim.fs.joinpath(deep, 'app.rb'))
vim.fn.writefile({}, vim.fs.joinpath(loose, 'gem.rb'))

local up = lsp._search_upward

-- ── marker found ─────────────────────────────────────────────────────────────

eq(up({ 'Gemfile' }, vim.fs.joinpath(project, 'Gemfile')),
  project, 'marker in the file own directory')

eq(up({ 'Gemfile' }, vim.fs.joinpath(deep, 'app.rb')),
  project, 'marker in an ancestor directory')

eq(up({ 'Gemfile' }, deep),
  project, 'bufpath is a directory, not a file')

eq(up({ 'Shipfile', 'Gemfile' }, vim.fs.joinpath(deep, 'app.rb')),
  project, 'any of several markers matches')

-- A directory marker counts too, same as a file marker.
vim.fn.mkdir(vim.fs.joinpath(project, '.git'))
eq(up({ '.git' }, vim.fs.joinpath(deep, 'app.rb')),
  project, 'directory marker')

-- ── no marker: must terminate ────────────────────────────────────────────────
-- This is the `gd`-into-a-gem case. The walk runs all the way to "/" where
-- vim.fs.dirname("/") == "/", and has to stop there rather than spin.
-- The marker name is deliberately one nothing on the filesystem can have.

eq(up({ '.__nvim_spec_marker__' }, vim.fs.joinpath(loose, 'gem.rb')),
  nil, 'no marker up to the filesystem root terminates and returns nil')

eq(up({ '.__nvim_spec_marker__' }, '/'),
  nil, 'filesystem root itself terminates')

-- ── degenerate input ─────────────────────────────────────────────────────────

eq(up({ 'Gemfile' }, ''), nil, 'unnamed buffer')
eq(up({ 'Gemfile' }, nil), nil, 'nil path')
eq(up({}, vim.fs.joinpath(deep, 'app.rb')), nil, 'no markers to look for')

vim.fn.delete(tmp, 'rf')

print(('ok - %d checks passed'):format(checks))
