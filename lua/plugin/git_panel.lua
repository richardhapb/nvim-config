-- Zed-style git panel. Opens a dedicated tab with a narrow file list on the
-- left (grouped into Staged / Changes) and a live diff on the right: just move
-- the cursor onto a file and its diff appears. Stage, unstage and discard
-- happen in place without leaving the panel.

local M = {}

local PANEL_WIDTH = 44

local ns = vim.api.nvim_create_namespace("git_panel")

---Define the panel's highlight groups as links to existing groups, so they
---follow the active colorscheme. `default = true` lets users override them.
local function define_highlights()
  local links = {
    GitPanelHeader    = "Title",          -- section titles
    GitPanelCount     = "Comment",        -- "(n)" counts
    GitPanelDir       = "Directory",      -- directory names
    GitPanelFold      = "Comment",        -- ▸ / ▾ icons
    GitPanelFile      = "Normal",         -- tracked file names
    GitPanelUntracked = "Comment",        -- untracked file names (muted)
    GitPanelAdded     = "GitSignsAdd",    -- A / ? status letter (green)
    GitPanelModified  = "GitSignsChange", -- M status letter (yellow)
    GitPanelDeleted   = "GitSignsDelete", -- D status letter (red)
    GitPanelRenamed   = "Special",        -- R / C status letter
    GitPanelCountAdd  = "GitSignsAdd",    -- +N additions
    GitPanelCountDel  = "GitSignsDelete", -- -N deletions
  }
  for from, to in pairs(links) do
    vim.api.nvim_set_hl(0, from, { link = to, default = true })
  end
end

local state = {
  tab = nil,        ---@type integer?
  panel_win = nil,  ---@type integer?
  panel_buf = nil,  ---@type integer?
  diff_win = nil,   ---@type integer?
  diff_buf = nil,   ---@type integer?
  line_map = {},    ---@type table<integer, table> panel line -> file entry
  dir_map = {},     ---@type table<integer, string> panel line -> directory path
  collapsed = {},   ---@type table<string, boolean> collapsed directory paths
}

---Run git synchronously in the cwd. Returns stdout (even on non-zero exit, so
---callers that expect diffs to "fail" with code 1 still get output).
---@param args string[]
---@return string stdout, integer code
local function git(args)
  local res = vim.system(vim.list_extend({ "git" }, args), { text = true }):wait()
  return res.stdout or "", res.code
end

---Parse `git diff --numstat` output into a path -> {add, del} map.
---@param text string
---@return table<string, {add: integer?, del: integer?}>
local function parse_numstat(text)
  local map = {}
  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    local a, d, p = line:match("^(%S+)\t(%S+)\t(.+)$")
    if p then
      map[p] = { add = tonumber(a), del = tonumber(d) } -- tonumber("-") == nil (binary)
    end
  end
  return map
end

---Collect staged and unstaged entries (with line-change counts) from git.
---@return table[] staged, table[] unstaged
local function collect()
  local out, code = git({ "status", "--porcelain=v1", "-u" })
  local staged, unstaged = {}, {}
  if code ~= 0 then
    return staged, unstaged
  end
  for _, line in ipairs(vim.split(out, "\n", { plain = true })) do
    if #line >= 4 then
      local x, y = line:sub(1, 1), line:sub(2, 2)
      local path = line:sub(4)
      -- Renames are "old -> new"; track the new path.
      if path:find(" %-> ") then
        path = path:match(" %-> (.+)$")
      end
      if x ~= " " and x ~= "?" then
        table.insert(staged, { path = path, code = x .. y, staged = true })
      end
      if y ~= " " then
        table.insert(unstaged, { path = path, code = x .. y, staged = false, untracked = (x == "?") })
      end
    end
  end

  -- Attach +/- line counts.
  local staged_ns = parse_numstat((git({ "diff", "--cached", "--numstat" })))
  local work_ns = parse_numstat((git({ "diff", "--numstat" })))
  for _, e in ipairs(staged) do
    local s = staged_ns[e.path]
    if s then e.add, e.del = s.add, s.del end
  end
  for _, e in ipairs(unstaged) do
    if e.untracked then
      local ok, file_lines = pcall(vim.fn.readfile, e.path)
      e.add, e.del = ok and #file_lines or nil, 0
    else
      local s = work_ns[e.path]
      if s then e.add, e.del = s.add, s.del end
    end
  end

  return staged, unstaged
end

---@return table? entry under the cursor in the panel
local function entry_under_cursor()
  if not (state.panel_win and vim.api.nvim_win_is_valid(state.panel_win)) then
    return nil
  end
  local lnum = vim.api.nvim_win_get_cursor(state.panel_win)[1]
  return state.line_map[lnum]
end

---Make sure the diff scratch buffer exists and is shown in the diff window.
local function ensure_diff_buf()
  if not (state.diff_buf and vim.api.nvim_buf_is_valid(state.diff_buf)) then
    state.diff_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.diff_buf].buftype = "nofile"
    vim.bo[state.diff_buf].bufhidden = "hide"
    vim.bo[state.diff_buf].swapfile = false
  end
  if state.diff_win and vim.api.nvim_win_is_valid(state.diff_win)
      and vim.api.nvim_win_get_buf(state.diff_win) ~= state.diff_buf then
    vim.api.nvim_win_set_buf(state.diff_win, state.diff_buf)
  end
end

---Render the diff for an entry into the diff window.
---@param entry table?
local function show_diff(entry)
  if not (state.diff_win and vim.api.nvim_win_is_valid(state.diff_win)) then
    return
  end
  ensure_diff_buf()

  local out = ""
  if entry then
    if entry.untracked then
      out = select(1, git({ "diff", "--no-index", "--", "/dev/null", entry.path }))
    elseif entry.staged then
      out = select(1, git({ "diff", "--staged", "--", entry.path }))
    else
      out = select(1, git({ "diff", "--", entry.path }))
    end
  end

  vim.bo[state.diff_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.diff_buf, 0, -1, false, vim.split(out, "\n", { plain = true }))
  vim.bo[state.diff_buf].modifiable = false
  vim.bo[state.diff_buf].filetype = "diff"
end

---Insert an entry into a directory tree keyed by its path components.
---@param root table
---@param entry table
local function tree_insert(root, entry)
  local parts = vim.split(entry.path, "/", { plain = true })
  local node = root
  for i = 1, #parts - 1 do
    local dir = parts[i]
    node.dirs[dir] = node.dirs[dir] or { dirs = {}, files = {} }
    node = node.dirs[dir]
  end
  table.insert(node.files, { name = parts[#parts], entry = entry })
end

local LETTER_HL = {
  A = "GitPanelAdded",
  ["?"] = "GitPanelAdded",
  M = "GitPanelModified",
  D = "GitPanelDeleted",
  R = "GitPanelRenamed",
  C = "GitPanelRenamed",
}

---The single status letter shown in the gutter for an entry.
---@param entry table
---@return string
local function status_letter(entry)
  if entry.untracked then return "?" end
  local ch = entry.staged and entry.code:sub(1, 1) or entry.code:sub(2, 2)
  return ch ~= " " and ch or "M"
end

---Render a tree node into lines: directories first (sorted), then files.
---Single-child directory chains are collapsed visually (e.g. `lua/config/`),
---and any directory in `state.collapsed` hides its children.
---@param node table
---@param depth integer
---@param prefix string accumulated path of the parent directory
---@param emit fun(text: string): integer appends a line, returns its number
---@param hl fun(line: integer, c0: integer, c1: integer, group: string)
local function render_tree(node, depth, prefix, emit, hl)
  local indent = string.rep("  ", depth)

  local dirnames = vim.tbl_keys(node.dirs)
  table.sort(dirnames)
  for _, name in ipairs(dirnames) do
    local child, label = node.dirs[name], name
    local path = prefix == "" and name or (prefix .. "/" .. name)
    -- Collapse single-child directory chains into one row.
    while vim.tbl_count(child.dirs) == 1 and #child.files == 0 do
      local only = next(child.dirs)
      label = label .. "/" .. only
      path = path .. "/" .. only
      child = child.dirs[only]
    end

    local folded = state.collapsed[path] == true
    local icon = folded and "▸" or "▾"
    -- "  " left gutter keeps directory icons aligned with file names, while the
    -- status-letter column for files stays flush at column 0.
    local row = "  " .. indent .. icon .. " " .. label .. "/"
    local ln = emit(row)
    state.dir_map[ln] = path
    local icon_c0 = 2 + #indent
    hl(ln, icon_c0, icon_c0 + #icon, "GitPanelFold")
    hl(ln, icon_c0 + #icon + 1, -1, "GitPanelDir")
    if not folded then
      render_tree(child, depth + 1, path, emit, hl)
    end
  end

  table.sort(node.files, function(a, b) return a.name < b.name end)
  for _, f in ipairs(node.files) do
    local e = f.entry
    local letter = status_letter(e)
    local head = letter .. " " .. indent -- status letter at col 0, then gutter + indent
    local name_c0 = #head
    local text = head .. f.name

    -- Append +adds / -dels change counts.
    local counts = {}
    if (e.add and e.add > 0) or (e.del and e.del > 0) then
      text = text .. "  "
      if e.add and e.add > 0 then
        local c0 = #text
        text = text .. "+" .. e.add
        counts[#counts + 1] = { c0, #text, "GitPanelCountAdd" }
      end
      if e.del and e.del > 0 then
        if #counts > 0 then text = text .. " " end
        local c0 = #text
        text = text .. "-" .. e.del
        counts[#counts + 1] = { c0, #text, "GitPanelCountDel" }
      end
    end

    local ln = emit(text)
    state.line_map[ln] = e
    hl(ln, 0, 1, LETTER_HL[letter] or "GitPanelModified")                          -- status letter
    hl(ln, name_c0, name_c0 + #f.name, e.untracked and "GitPanelUntracked" or "GitPanelFile") -- filename
    for _, c in ipairs(counts) do
      hl(ln, c[1], c[2], c[3])
    end
  end
end

---Rebuild the panel listing.
local function render()
  if not (state.panel_buf and vim.api.nvim_buf_is_valid(state.panel_buf)) then
    return
  end
  local staged, unstaged = collect()
  local lines, hls = {}, {}
  state.line_map, state.dir_map = {}, {}

  local function emit(text)
    table.insert(lines, text)
    return #lines
  end

  local function hl(line, c0, c1, group)
    table.insert(hls, { line = line, c0 = c0, c1 = c1, group = group })
  end

  local function section(title, entries)
    local ln = emit(("%s (%d)"):format(title, #entries))
    hl(ln, 0, #title, "GitPanelHeader")
    hl(ln, #title, -1, "GitPanelCount")
    local root = { dirs = {}, files = {} }
    for _, e in ipairs(entries) do
      tree_insert(root, e)
    end
    render_tree(root, 1, "", emit, hl)
  end

  section("Staged", staged)
  emit("")
  section("Changes", unstaged)

  vim.bo[state.panel_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.panel_buf, 0, -1, false, lines)
  vim.bo[state.panel_buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.panel_buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    local len = #lines[h.line]
    local c0 = math.max(0, math.min(h.c0, len))
    local c1 = math.max(c0, math.min(h.c1 < 0 and len or h.c1, len))
    vim.api.nvim_buf_set_extmark(state.panel_buf, ns, h.line - 1, c0,
      { end_col = c1, hl_group = h.group })
  end
end

---Refresh listing + diff under cursor.
local function refresh()
  render()
  show_diff(entry_under_cursor())
end

local function stage()
  local e = entry_under_cursor()
  if not e then return end
  git({ "add", "--", e.path })
  refresh()
end

local function unstage()
  local e = entry_under_cursor()
  if not e then return end
  git({ "restore", "--staged", "--", e.path })
  refresh()
end

local function discard()
  local e = entry_under_cursor()
  if not e then return end
  if vim.fn.confirm("Discard changes in " .. e.path .. "?", "&Yes\n&No", 2) ~= 1 then
    return
  end
  if e.untracked then
    vim.fn.delete(e.path)
  else
    git({ "restore", "--", e.path })
  end
  refresh()
end

---Move the cursor to the next/previous file entry, skipping headers/blanks.
---@param dir 1|-1
local function goto_file(dir)
  if not (state.panel_win and vim.api.nvim_win_is_valid(state.panel_win)) then
    return
  end
  local last = vim.api.nvim_buf_line_count(state.panel_buf)
  local lnum = vim.api.nvim_win_get_cursor(state.panel_win)[1]
  for l = lnum + dir, dir > 0 and last or 1, dir do
    if state.line_map[l] then
      vim.api.nvim_win_set_cursor(state.panel_win, { l, 0 })
      show_diff(state.line_map[l])
      return
    end
  end
end

---Bind file navigation (]c / [c) onto a buffer. goto_file drives the panel
---cursor directly, so it works no matter which buffer/window is focused.
---@param buf integer
local function set_nav_keys(buf)
  local o = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "]c", function() goto_file(1) end, vim.tbl_extend("force", o, { desc = "Next file" }))
  vim.keymap.set("n", "[c", function() goto_file(-1) end, vim.tbl_extend("force", o, { desc = "Prev file" }))
end

---Open the file under the cursor for real editing, in the diff window.
---This is the *only* action that loads an editable file; plain navigation
---(]c / [c, cursor movement) just previews the diff.
local function open_file()
  local e = entry_under_cursor()
  if not e then return end
  vim.api.nvim_set_current_win(state.diff_win)
  vim.cmd.edit(vim.fn.fnameescape(e.path))
  -- So ]c / [c keep working while you view the file you just opened. They
  -- still only preview the next/prev diff -- they never open another file.
  set_nav_keys(vim.api.nvim_get_current_buf())
end

---Toggle the collapsed state of the directory under the cursor.
local function toggle_fold()
  if not (state.panel_win and vim.api.nvim_win_is_valid(state.panel_win)) then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(state.panel_win)[1]
  local path = state.dir_map[lnum]
  if not path then return end

  state.collapsed[path] = not state.collapsed[path] or nil
  render()
  -- The toggled directory row stays at the same line, so keep the cursor there.
  local clamped = math.min(lnum, vim.api.nvim_buf_line_count(state.panel_buf))
  vim.api.nvim_win_set_cursor(state.panel_win, { clamped, 0 })
end

---Context action: fold/unfold a directory, or open a file.
local function primary_action()
  if state.dir_map[vim.api.nvim_win_get_cursor(state.panel_win)[1]] then
    toggle_fold()
  else
    open_file()
  end
end

function M.close()
  if state.tab and vim.api.nvim_tabpage_is_valid(state.tab) then
    vim.cmd.tabclose()
  end
  state.tab, state.panel_win, state.panel_buf, state.diff_win = nil, nil, nil, nil
end

function M.open()
  if state.tab and vim.api.nvim_tabpage_is_valid(state.tab) then
    vim.api.nvim_set_current_tabpage(state.tab)
    refresh()
    return
  end

  if select(2, git({ "rev-parse", "--is-inside-work-tree" })) ~= 0 then
    vim.notify("Not inside a git repository", vim.log.levels.WARN)
    return
  end

  vim.cmd.tabnew()
  state.tab = vim.api.nvim_get_current_tabpage()

  -- Right window holds the diff.
  state.diff_win = vim.api.nvim_get_current_win()
  vim.wo[state.diff_win].number = false
  vim.wo[state.diff_win].relativenumber = false
  ensure_diff_buf()

  -- Left window holds the file list.
  vim.cmd("topleft vsplit")
  state.panel_win = vim.api.nvim_get_current_win()
  state.panel_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.panel_win, state.panel_buf)
  vim.api.nvim_win_set_width(state.panel_win, PANEL_WIDTH)

  local wo = vim.wo[state.panel_win]
  wo.number, wo.relativenumber = false, false
  wo.signcolumn, wo.wrap = "no", false
  wo.cursorline, wo.winfixwidth = true, true
  -- Subtle panel background + no end-of-buffer tildes for a cleaner sidebar.
  wo.winhighlight = "Normal:NormalFloat,CursorLine:CursorLine,EndOfBuffer:NormalFloat"
  wo.fillchars = "eob: "
  wo.statuscolumn = "  "

  local bo = vim.bo[state.panel_buf]
  bo.buftype, bo.bufhidden, bo.swapfile = "nofile", "wipe", false
  bo.filetype = "gitpanel"

  local opts = { buffer = state.panel_buf, silent = true, nowait = true }
  vim.keymap.set("n", "s", stage, vim.tbl_extend("force", opts, { desc = "Stage file" }))
  vim.keymap.set("n", "u", unstage, vim.tbl_extend("force", opts, { desc = "Unstage file" }))
  vim.keymap.set("n", "X", discard, vim.tbl_extend("force", opts, { desc = "Discard changes" }))
  vim.keymap.set("n", "R", refresh, vim.tbl_extend("force", opts, { desc = "Refresh" }))
  vim.keymap.set("n", "<CR>", primary_action, vim.tbl_extend("force", opts, { desc = "Open file / fold dir" }))
  vim.keymap.set("n", "=", toggle_fold, vim.tbl_extend("force", opts, { desc = "Fold/unfold directory" }))
  vim.keymap.set("n", "q", M.close, vim.tbl_extend("force", opts, { desc = "Close panel" }))
  -- File navigation works from the list, the diff pane, and any file opened
  -- into the diff window (see open_file).
  set_nav_keys(state.panel_buf)
  set_nav_keys(state.diff_buf)

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = state.panel_buf,
    callback = function() show_diff(entry_under_cursor()) end,
  })

  refresh()
end

function M.toggle()
  if state.tab and vim.api.nvim_tabpage_is_valid(state.tab) then
    M.close()
  else
    M.open()
  end
end

function M.setup()
  define_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("GitPanelHighlights", { clear = true }),
    callback = define_highlights,
  })
  vim.api.nvim_create_user_command("GitPanel", M.open, { desc = "Open the git panel" })
  vim.keymap.set("n", "<leader>gs", M.toggle, { silent = true, desc = "Git panel (Zed-like)" })
end

return M
