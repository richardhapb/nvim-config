local M = {}

---@class MarkdownListMarker
---@field indent string
---@field content string
---@field next_prefix string

---@param before string text of the line up to the cursor
---@return MarkdownListMarker?
local function match_marker(before)
  local indent, bullet, sp, rest = before:match("^(%s*)([%-%*%+])(%s+)(.*)$")
  if indent then
    local cbsp, cbcontent = rest:match("^%[[ xX]%](%s+)(.*)$")
    if cbsp then
      return { indent = indent, content = cbcontent, next_prefix = indent .. bullet .. sp .. "[ ]" .. cbsp }
    end
    return { indent = indent, content = rest, next_prefix = indent .. bullet .. sp }
  end

  local indent2, num, punct, sp2, rest2 = before:match("^(%s*)(%d+)([%.%)])(%s+)(.*)$")
  if indent2 then
    return { indent = indent2, content = rest2, next_prefix = indent2 .. tostring(tonumber(num) + 1) .. punct .. sp2 }
  end

  return nil
end

--- Work out how <CR> should behave on a markdown list line.
--- Returns nil when the line isn't a list item, so the caller falls back to
--- the normal <CR> (autoindent and all) instead of touching the buffer.
---@param line string current line contents
---@param col integer 0-indexed byte column of the cursor
---@return { kind: "exit", line: string }|{ kind: "continue", line: string, new_line: string, cursor_col: integer }|nil
function M._compute(line, col)
  local before = line:sub(1, col)
  local after = line:sub(col + 1)

  local m = match_marker(before)
  if not m then
    return nil
  end

  -- An empty item (marker with no text either side of the cursor) exits the
  -- list instead of continuing it: the marker is stripped, no new line added.
  if m.content:match("^%s*$") and after:match("^%s*$") then
    return { kind = "exit", line = m.indent }
  end

  return {
    kind = "continue",
    line = before,
    new_line = m.next_prefix .. after,
    cursor_col = #m.next_prefix,
  }
end

--- <CR> handler for insert mode. Returns false when the line isn't a list
--- item, so the caller can feed a real <CR> and get normal autoindent back.
---@return boolean handled
function M.on_enter()
  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  local result = M._compute(line, col)
  if not result then
    return false
  end

  if result.kind == "exit" then
    vim.api.nvim_set_current_line(result.line)
    vim.api.nvim_win_set_cursor(0, { row, #result.line })
    return true
  end

  vim.api.nvim_set_current_line(result.line)
  vim.api.nvim_buf_set_lines(0, row, row, false, { result.new_line })
  vim.api.nvim_win_set_cursor(0, { row + 1, result.cursor_col })
  return true
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("MarkdownLists", { clear = true }),
    pattern = "markdown",
    callback = function(ev)
      vim.keymap.set("i", "<CR>", function()
        if not M.on_enter() then
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
        end
      end, { buffer = ev.buf, silent = true })
    end,
  })
end

return M
