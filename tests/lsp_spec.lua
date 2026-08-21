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

-- ── start_client ─────────────────────────────────────────────────────────────
-- :LspStart used to hand vim.lsp.start() the config verbatim, so a `root_dir`
-- *function* reached the transport, which stat()s it: "bad argument #1 to
-- 'fs_stat' (string expected, got function)". start_client resolves it first.

local real_config, real_start = vim.lsp.config, vim.lsp.start

---Run start_client against a stub registry, returning (started, config, opts).
local function start(name, registry)
  local seen_config, seen_opts
  vim.lsp.config = registry
  vim.lsp.start = function(config, opts)
    seen_config, seen_opts = config, opts
    return 1
  end

  local ok, started = pcall(lsp.start_client, name, 0)
  -- The root_dir-function path defers the start through vim.schedule().
  vim.wait(200, function() return seen_config ~= nil end)

  vim.lsp.config, vim.lsp.start = real_config, real_start
  if not ok then
    io.stderr:write(('FAIL start_client(%s) raised\n  %s\n'):format(name, started))
    os.exit(1)
  end
  return started, seen_config, seen_opts
end

vim.cmd.edit(vim.fs.joinpath(deep, 'app.rb'))

local fn_registry = {
  server = { cmd = { 'server' }, root_dir = lsp.root_dir({ 'Gemfile' }) },
}

local started, config, opts = start('server', fn_registry)
eq(started, true, 'start_client reports a start')
-- resolve(): on macOS :edit reports the buffer under /private/var, tmp is /var.
eq(vim.fn.resolve(config.root_dir), vim.fn.resolve(project),
  'root_dir function is resolved before vim.lsp.start')
eq(config.cmd, { 'server' }, 'the rest of the config is forwarded')
eq(opts.bufnr, 0, 'the client is started for the given buffer')
eq(type(fn_registry.server.root_dir), 'function',
  'the enabled config keeps its root_dir function')

local _, config = start('server', {
  server = { cmd = { 'server' }, root_dir = '/tmp' },
})
eq(config.root_dir, '/tmp', 'a plain root_dir is passed through')

local _, _, opts = start('server', {
  server = { cmd = { 'server' }, root_markers = { '.git' } },
})
eq(opts._root_markers, { '.git' }, 'root_markers reach vim.lsp.start')

local started, config = start('nope', {})
eq(started, false, 'an unknown name is reported, not started')
eq(config, nil, 'an unknown name starts nothing')

-- A root_dir() that never calls on_dir (an excluded project) must not start.
local _, config = start('server', {
  server = { cmd = { 'server' }, root_dir = function() end },
})
eq(config, nil, 'an unresolved root_dir starts nothing')

vim.fn.delete(tmp, 'rf')

print(('ok - %d checks passed'):format(checks))
