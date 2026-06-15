-- Pandoc fenced-div renderer. A small complement to render-markdown.nvim that
-- styles pandoc fenced divs:
--
--     ::::: decision
--     ::: verdict
--     ✓ Safe --- no patch marker required
--     :::
--
--     Body prose explaining the decision.
--
--     ::: rationale
--     The existing patch marker is unaffected.
--     :::
--     :::::
--
-- Fences open with a class (`::: decision`) and close with bare colons (`:::`).
-- Nesting is matched with a stack, so any number of colons works and deeper
-- blocks win when styles overlap (the convention of using more colons for the
-- outer block is honoured but not required).
--
-- The palette mirrors the HTML export style: a surface-coloured "decision" card
-- with an uppercase title, a green "verdict", muted "rationale", plus warn/note
-- callouts with a left bar in the sign column.

local M = {}

local ns = vim.api.nvim_create_namespace("pandoc_div")

-- Palette lifted from the reference design (dark).
local palette = {
  surface = "#1a1d27",
  muted   = "#8b91a3",
  accent  = "#6c8cff",
  warn    = "#f0a04b",
  danger  = "#e05c5c",
  ok      = "#4caf82",
}

-- Per-class styling.
--   label    show an uppercased callout title on the opening fence
--   icon     glyph rendered before the title
--   accent   colour for the title and the left bar
--   bg       full-line background tint (optional)
--   text     recolour the body prose (optional)
--   bold     bold the body prose
local default_classes = {
  decision  = { label = true, icon = "󰔡", accent = palette.accent, bg = palette.surface },
  note      = { label = true, icon = "", accent = palette.accent, bg = "#13162a" },
  info      = { label = true, icon = "", accent = palette.accent, bg = "#13162a" },
  risk      = { label = true, icon = "", accent = palette.warn, bg = "#1d1a12" },
  warning   = { label = true, icon = "", accent = palette.warn, bg = "#1d1a12" },
  danger    = { label = true, icon = "", accent = palette.danger, bg = "#2a0f0f" },
  verdict   = { label = false, accent = palette.ok, text = palette.ok, bold = true },
  rationale = { label = false, accent = palette.muted, text = palette.muted },
}

local config = {
  filetypes = { "markdown", "pandoc", "rmd", "quarto", "markdown.pandoc" },
  bar = "▎",
  classes = default_classes,
  -- Fallback for any class without an explicit entry above.
  fallback = { label = true, icon = "", accent = palette.muted },
}

-- Highlight group names derived per class, e.g. PandocDivDecisionTitle.
local function group(class, suffix)
  return "PandocDiv" .. class:sub(1, 1):upper() .. class:sub(2):gsub("[^%w]", "") .. suffix
end

local function define_highlights()
  for class, style in pairs(config.classes) do
    vim.api.nvim_set_hl(0, group(class, "Title"),
      { fg = style.accent, bold = true, default = true })
    vim.api.nvim_set_hl(0, group(class, "Bar"),
      { fg = style.accent, default = true })
    if style.bg then
      vim.api.nvim_set_hl(0, group(class, "Bg"), { bg = style.bg, default = true })
    end
    if style.text then
      vim.api.nvim_set_hl(0, group(class, "Text"),
        { fg = style.text, bold = style.bold, default = true })
    end
  end
end

---Extract the div class from a fence's info string.
---Handles bare classes (`decision`) and attribute lists (`{.decision #id}`).
---@param info string
---@return string?
local function parse_class(info)
  info = vim.trim(info)
  if info == "" then return nil end
  local inner = info:match("^{(.*)}$")
  if inner then
    return inner:match("%.([%w_%-]+)")
  end
  return info:match("^([%w_%-]+)")
end

---Decorate a single matched block.
---@param buf integer
---@param open table opening fence: { line, class, indent, depth }
---@param close_line integer 0-based line of the closing fence
---@param lines string[] buffer lines (1-based)
local function draw_block(buf, open, close_line, lines)
  local style = config.classes[open.class] or config.fallback
  local prio = 100 + open.depth
  local bar_hl = config.classes[open.class] and group(open.class, "Bar") or "Comment"
  local bg_hl = style.bg and group(open.class, "Bg") or nil
  local text_hl = style.text and group(open.class, "Text") or nil

  -- Conceal the opening fence; optionally replace it with a callout title.
  local open_text = lines[open.line + 1] or ""
  vim.api.nvim_buf_set_extmark(buf, ns, open.line, 0, {
    end_col = #open_text,
    conceal = "",
    priority = prio,
  })
  if style.label then
    local title = (style.icon and style.icon ~= "" and (style.icon .. " ") or "")
        .. open.class:upper()
    vim.api.nvim_buf_set_extmark(buf, ns, open.line, 0, {
      virt_text = { { title, group(open.class, "Title") } },
      virt_text_pos = "inline",
      priority = prio,
    })
  end

  -- Conceal the closing fence.
  local close_text = lines[close_line + 1] or ""
  vim.api.nvim_buf_set_extmark(buf, ns, close_line, 0, {
    end_col = #close_text,
    conceal = "",
    priority = prio,
  })

  -- Background tint, left bar, and body recolour across the whole block.
  for l = open.line, close_line do
    local mark = {
      sign_text = config.bar,
      sign_hl_group = bar_hl,
      priority = prio,
    }
    if bg_hl then mark.line_hl_group = bg_hl end
    vim.api.nvim_buf_set_extmark(buf, ns, l, 0, mark)

    if text_hl and l > open.line and l < close_line then
      local t = lines[l + 1] or ""
      if #t > 0 then
        vim.api.nvim_buf_set_extmark(buf, ns, l, 0, {
          end_col = #t,
          hl_group = text_hl,
          priority = prio,
        })
      end
    end
  end
end

---Re-render every fenced div in the buffer.
---@param buf integer
function M.render(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not vim.tbl_contains(config.filetypes, vim.bo[buf].filetype) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local stack = {}
  for i, line in ipairs(lines) do
    local indent, colons, rest = line:match("^(%s*)(:::+)%s*(.-)%s*$")
    if colons then
      local class = parse_class(rest)
      if class then
        table.insert(stack, { line = i - 1, class = class, indent = #indent, depth = #stack })
      else
        local open = table.remove(stack)
        if open then
          draw_block(buf, open, i - 1, lines)
        end
      end
    end
  end
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  define_highlights()

  local augroup = vim.api.nvim_create_augroup("PandocDiv", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = define_highlights,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = config.filetypes,
    callback = function(ev)
      -- Conceal needs a window with conceallevel set; render-markdown usually
      -- raises it already, but guard the standalone case.
      if vim.wo.conceallevel < 2 then vim.wo.conceallevel = 2 end
      M.render(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = augroup,
    callback = function(ev)
      M.render(ev.buf)
    end,
  })

  vim.api.nvim_create_user_command("PandocDivRender", function()
    M.render(0)
  end, { desc = "Re-render pandoc fenced divs" })
end

return M
