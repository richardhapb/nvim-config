-- Diffview layout modes.
--
-- Browsing a diff and reviewing an MR want different layouts, and diffview's
-- layout settings are global: whoever opens a view last decides what the next
-- one looks like. So both entry points set their mode right before opening.
--
-- Browsing gets the single-window treatments -- `diff1_inline` on a narrow
-- terminal, `diff1_raw` for added/deleted files, which have nothing to compare
-- against. Reviewing can't: gitlab.nvim's reviewer indexes `cur_layout.a` and
-- `cur_layout.b` directly (diagnostics, comment placement, jumps), so a layout
-- with only a `b` window fails with "attempt to index field 'a' (a nil value)"
-- the moment you open an added file. Reviews therefore stay on a two-window
-- layout, where the missing side is diffview's `diffview://null` placeholder --
-- the case gitlab.nvim recognises and skips by name.

local M = {}

-- Below this width side-by-side panes are too narrow to read: anything long
-- runs off the edge.
M.NARROW_COLUMNS = 190

-- `g<C-x>` cycles these in-view when the width guess is wrong for a file.
M.browse_cycle = { "diff1_inline", "diff2_vertical", "diff2_horizontal" }
M.review_cycle = { "diff2_vertical", "diff2_horizontal" }

---Browsing layout for the current window width.
---@return string
M.layout = function()
  return vim.o.columns < M.NARROW_COLUMNS and "diff1_inline" or "diff2_horizontal"
end

---Apply `mode` to the resolved diffview config. Mutating the resolved config is
---deliberate: calling setup() again rebuilds it from defaults and drops the
---hooks configured at startup.
---@param mode "browse"|"review"
M.mode = function(mode)
  local view = require("diffview.config").get_config().view

  if mode == "review" then
    -- Stack the panes instead of collapsing to one window when narrow.
    view.default.layout = vim.o.columns < M.NARROW_COLUMNS and "diff2_vertical" or "diff2_horizontal"
    view.one_sided_layout = "default"
    view.cycle_layouts.default = M.review_cycle
  else
    view.default.layout = M.layout()
    view.file_history.layout = view.default.layout
    view.one_sided_layout = "raw"
    view.cycle_layouts.default = M.browse_cycle
  end

  return view.default.layout
end

---Wrap a gitlab.nvim reviewer so review mode is set before it opens diffview.
---gitlab.nvim runs `DiffviewOpen` for the MR's diff refs itself, so wrapping
---`open` is the only way to get in front of it. Idempotent: re-sourcing the
---config must not stack wrappers.
---@param reviewer table gitlab.reviewer
---@return table reviewer
M.pin_reviewer = function(reviewer)
  if reviewer.__diffview_mode_pinned then
    return reviewer
  end

  local open = reviewer.open
  reviewer.open = function(...)
    M.mode("review")
    return open(...)
  end
  reviewer.__diffview_mode_pinned = true
  M.repin_on_tab_enter(reviewer)

  return reviewer
end

---Re-apply review mode on entering the review tab. Layouts are built per file,
---as you walk the file panel -- so browsing a diff in another tab mid-review
---would leave the next file in the review on a browsing layout.
---@param reviewer table gitlab.reviewer
M.repin_on_tab_enter = function(reviewer)
  vim.api.nvim_create_autocmd("TabEnter", {
    group = vim.api.nvim_create_augroup("DiffviewReviewMode", { clear = true }),
    desc = "Keep gitlab.nvim's review tab on a two-window diff layout",
    callback = function()
      if reviewer.tabid ~= nil and reviewer.tabid == vim.api.nvim_get_current_tabpage() then
        M.mode("review")
      end
    end,
  })
end

return M
