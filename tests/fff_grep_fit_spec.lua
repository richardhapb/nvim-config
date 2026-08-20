-- Regression tests for plugin/fff_grep_fit.lua.
-- Run with:  nvim --headless -l tests/fff_grep_fit_spec.lua
-- Exits non-zero on the first failed assertion.

local cfg = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))
package.path = vim.fs.joinpath(cfg, 'lua', '?.lua') .. ';' .. package.path

local checks = 0
local function eq(got, want, what)
  checks = checks + 1
  if got ~= want then
    io.stderr:write(('not ok - %s\n  got:  %s\n  want: %s\n'):format(what, vim.inspect(got), vim.inspect(want)))
    os.exit(1)
  end
end

local function paths(list)
  local out = {}
  for _, p in ipairs(list) do
    out[#out + 1] = p
  end
  return out
end

local fit = require 'plugin.fff_grep_fit'

-- One group: 4 matches plus a single header line fill 5 rows.
eq(fit.fit(paths { 'a', 'a', 'a', 'a', 'a', 'a' }, 5, 1), 4, 'one group leaves a row for its header')

-- A header per item: each item costs 2 rows.
eq(fit.fit(paths { 'a', 'b', 'c', 'd' }, 6, 1), 3, 'every item opening a group costs two rows')

-- Nothing to trim when the page already fits.
eq(fit.fit(paths { 'a', 'b' }, 64, 1), 2, 'a page that fits is kept whole')

-- An unrendered cursor leaves the selection stuck, so the cursor wins over the
-- row budget.
eq(fit.fit(paths { 'a', 'b', 'c', 'd', 'e' }, 4, 5), 5, 'cursor is rendered even past the budget')

-- At least one item, however tight the window.
eq(fit.fit(paths { 'a', 'b' }, 1, 1), 1, 'never trims to an empty list')
eq(fit.fit({}, 10, 1), 0, 'no items, nothing to keep')

-- The measured case: 64 rows, one group of 3 matches then a group per match.
-- 3 matches + 1 header = 4 rows, then 2 rows each -> 4 + 2*30 = 64.
local measured = { 'a', 'a', 'a' }
for i = 1, 40 do
  measured[#measured + 1] = 'f' .. i
end
eq(fit.fit(measured, 64, 1), 33, 'header rows are charged against the window height')

-- fit_ctx rewrites the display range in place. A bottom prompt iterates
-- display_end -> display_start, so the trimmed bound is iter_start.
local bottom = {
  items = { { relative_path = 'a' }, { relative_path = 'b' }, { relative_path = 'c' } },
  win_height = 4,
  display_start = 1,
  display_end = 3,
  iter_start = 3,
  iter_end = 1,
  iter_step = -1,
  cursor = 1,
}
fit.fit_ctx(bottom)
eq(bottom.display_end, 2, 'bottom prompt: display_end trimmed to what fits')
eq(bottom.iter_start, 2, 'bottom prompt: iter_start follows display_end')
eq(bottom.iter_end, 1, 'bottom prompt: iter_end untouched')

-- A top prompt iterates display_start -> display_end, so iter_end moves.
local top = {
  items = { { relative_path = 'a' }, { relative_path = 'b' }, { relative_path = 'c' } },
  win_height = 4,
  display_start = 1,
  display_end = 3,
  iter_start = 1,
  iter_end = 3,
  iter_step = 1,
  cursor = 1,
}
fit.fit_ctx(top)
eq(top.display_end, 2, 'top prompt: display_end trimmed to what fits')
eq(top.iter_end, 2, 'top prompt: iter_end follows display_end')
eq(top.iter_start, 1, 'top prompt: iter_start untouched')

-- A page that fits is left exactly as it was.
local roomy = {
  items = { { relative_path = 'a' }, { relative_path = 'a' } },
  win_height = 64,
  display_start = 1,
  display_end = 2,
  iter_start = 2,
  iter_end = 1,
  iter_step = -1,
  cursor = 1,
}
fit.fit_ctx(roomy)
eq(roomy.display_end, 2, 'roomy page keeps every item')
eq(roomy.iter_start, 2, 'roomy page keeps its iteration bounds')

-- setup() wraps fff's renderer once, only touches grep renders, and survives a
-- re-source of init.lua.
local seen = {}
package.loaded['fff.picker_ui.list_renderer'] = {
  render = function(ctx)
    seen[#seen + 1] = ctx.display_end
    return {}, nil
  end,
}

local moves, full_renders = {}, 0
local fake_state = { mode = 'grep', cursor = 1, list_buf = nil, list_win = nil }
package.loaded['fff.picker_ui.picker_ui_state'] = { state = fake_state }
package.loaded['fff.picker_ui.picker_ui'] = {
  render_list = function() full_renders = full_renders + 1 end,
  render_after_cursor_move = function(old_cursor)
    moves[#moves + 1] = old_cursor
    return true
  end,
}

fit.setup()
local wrapped = package.loaded['fff.picker_ui.list_renderer'].render
fit.setup()
eq(package.loaded['fff.picker_ui.list_renderer'].render, wrapped, 'setup() is idempotent')

local function ctx_of(mode)
  return {
    mode = mode,
    items = { { relative_path = 'a' }, { relative_path = 'b' }, { relative_path = 'c' } },
    win_height = 4,
    display_start = 1,
    display_end = 3,
    iter_start = 3,
    iter_end = 1,
    iter_step = -1,
    cursor = 1,
  }
end

wrapped(ctx_of 'grep')
eq(seen[1], 2, 'grep renders are trimmed')
wrapped(ctx_of(nil))
eq(seen[2], 3, 'files renders are passed through untouched')

local suggested = ctx_of 'grep'
suggested.suggestion_source = 'files'
wrapped(suggested)
eq(seen[3], 3, 'suggestion renders are passed through untouched')

-- Cursor moves take the full render path only while rows are hidden, otherwise
-- an oversized buffer survives the scroll back down.
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'a', 'b', 'c', 'd', 'e', 'f' })
local win = vim.api.nvim_open_win(buf, false, {
  relative = 'editor',
  row = 0,
  col = 0,
  width = 10,
  height = 3,
  style = 'minimal',
})
fake_state.list_buf, fake_state.list_win = buf, win
eq(fit.overflows(fake_state), true, 'six lines in a three-row window overflow')

local move = package.loaded['fff.picker_ui.picker_ui'].render_after_cursor_move
fake_state.cursor = 2
eq(move(1), true, 'a move while overflowing is handled')
eq(full_renders, 1, 'overflow forces a full render')
eq(#moves, 0, 'overflow skips the two-row fast path')

fake_state.cursor = 2
eq(move(2), true, 'a no-op move falls through to fff')
eq(#moves, 1, 'a cursor that did not move is left to fff')

vim.api.nvim_win_set_height(win, 6)
eq(fit.overflows(fake_state), false, 'a window as tall as the buffer does not overflow')
fake_state.cursor = 3
move(2)
eq(full_renders, 1, 'no overflow keeps the fast path')
eq(#moves, 2, 'no overflow delegates to fff')

fake_state.mode = nil
fake_state.list_buf, fake_state.list_win = buf, win
vim.api.nvim_win_set_height(win, 3)
fake_state.cursor = 4
move(3)
eq(full_renders, 1, 'files mode is never forced through a full render')

vim.api.nvim_win_close(win, true)

print(('ok - %d checks'):format(checks))
