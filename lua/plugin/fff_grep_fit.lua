-- fff.nvim sizes a grep page in matches (`page_size = list window height`, in
-- picker_ui/search_manager.lua) but its grep renderer emits an extra file-group
-- header line per group. The buffer overflows the list window by one line per
-- group, and since content is anchored to the prompt the overflow falls off the
-- TOP: the first group's header goes with it, so the topmost matches render as
-- bare `:line:col` under the window title.
--
-- Trim items from the far end of the display range until the rendered rows fit.
-- Never trim past the cursor: list_renderer only moves the window cursor for an
-- item it actually rendered, so an unrendered cursor leaves the selection stuck.

local M = {}

--- How many items, counted from the prompt end, fit in `height` rows.
--- Each item costs one row plus a header row when it opens a file group. The
--- first rendered item always gets a header and headers sit between items with
--- differing paths, so the row count is the same in either iteration direction.
--- @param paths string[] item paths, ordered from the prompt end
--- @param height integer rows available in the list window
--- @param min_keep integer keep at least this many items (the cursor)
--- @return integer keep
function M.fit(paths, height, min_keep)
  local rows, keep = 0, 0
  for i = 1, #paths do
    local cost = (i == 1 or paths[i] ~= paths[i - 1]) and 2 or 1
    if rows + cost > height and keep > 0 and keep >= min_keep then break end
    rows = rows + cost
    keep = i
  end
  return keep
end

--- Shrink a grep render context in place so its rendered rows fit the window.
--- @param ctx table fff render context
function M.fit_ctx(ctx)
  local items, height = ctx.items, ctx.win_height
  local first, last = ctx.display_start, ctx.display_end
  if type(height) ~= 'number' or type(first) ~= 'number' or type(last) ~= 'number' then return end
  if not items or #items == 0 then return end

  local paths = {}
  for i = first, last do
    local item = items[i]
    paths[#paths + 1] = item and item.relative_path or ''
  end

  local cursor = type(ctx.cursor) == 'number' and ctx.cursor or first
  local keep = M.fit(paths, height, math.max(1, cursor - first + 1))
  local trimmed = first + keep - 1
  if trimmed >= last then return end

  ctx.display_end = trimmed
  -- A bottom prompt iterates display_end -> display_start and a top prompt the
  -- reverse, so the trimmed bound is iter_start or iter_end accordingly.
  if type(ctx.iter_step) == 'number' and ctx.iter_step < 0 then
    ctx.iter_start = trimmed
  else
    ctx.iter_end = trimmed
  end
end

--- True when the list buffer is taller than its window, i.e. rows are hidden.
--- @param state table fff picker state
--- @return boolean
function M.overflows(state)
  local buf, win = state.list_buf, state.list_win
  if not buf or not win then return false end
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then return false end
  return vim.api.nvim_buf_line_count(buf) > vim.api.nvim_win_get_height(win)
end

--- Cursor moves normally patch just the two affected rows, which cannot resize
--- an oversized buffer -- scrolling above the fitted range and back down would
--- otherwise leave the top rows hidden until the next query keystroke.
--- @param picker_ui table fff.picker_ui.picker_ui
--- @param state table fff picker state
local function wrap_cursor_move(picker_ui, state)
  local move = picker_ui.render_after_cursor_move
  picker_ui.render_after_cursor_move = function(old_cursor, ...)
    if
      old_cursor ~= state.cursor
      and state.mode == 'grep'
      and not state.suggestion_source
      and M.overflows(state)
    then
      picker_ui.render_list()
      return true
    end
    return move(old_cursor, ...)
  end
end

function M.setup()
  local ok, list_renderer = pcall(require, 'fff.picker_ui.list_renderer')
  if not ok or type(list_renderer.render) ~= 'function' then return end
  -- `<leader>I` re-sources init.lua; without this the wrappers stack.
  if list_renderer.__grep_fit then return end

  local render = list_renderer.render
  list_renderer.render = function(ctx, ...)
    -- Suggestion mode adds its own header lines and swaps the renderer, so the
    -- row arithmetic above does not hold there.
    if ctx and ctx.mode == 'grep' and not ctx.suggestion_source then pcall(M.fit_ctx, ctx) end
    return render(ctx, ...)
  end
  list_renderer.__grep_fit = true

  -- picker_ui copies the renderer's functions at load time, so navigation calls
  -- that copy rather than the renderer module.
  local picker_ok, picker_ui = pcall(require, 'fff.picker_ui.picker_ui')
  local state_ok, picker_state = pcall(require, 'fff.picker_ui.picker_ui_state')
  if not picker_ok or not state_ok then return end
  if type(picker_ui.render_after_cursor_move) ~= 'function' then return end
  if type(picker_ui.render_list) ~= 'function' then return end

  wrap_cursor_move(picker_ui, picker_state.state)
end

return M
