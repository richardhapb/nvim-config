-- Inline ASCII rendering of mermaid flowcharts. A complement to
-- render-markdown.nvim: it leaves the fenced source untouched (render-markdown
-- still styles the code block) and draws the rendered diagram as virtual lines
-- below it.
--
--     ```mermaid
--     graph LR
--       A[Activity] --> B{automate?}
--       B -->|yes| C[start_workflow]
--       B -->|no| D[OpsExceptionHandoff]
--     ```
--
-- Rendering is delegated to the `mermaid-ascii` binary
-- (github.com/AlexanderGrooff/mermaid-ascii), which understands
-- `graph TD/TB/LR`, `flowchart TD/TB/LR`, and `sequenceDiagram`. Any other
-- diagram type (class, state, ...) fails to parse; those blocks are left as
-- plain source, so nothing breaks — they simply aren't rendered.
--
-- The binary speaks only a subset of mermaid, so preprocess() rewrites each
-- block into that subset before rendering:
--
--   * graph/flowchart: it only recognizes the `[label]` node shape. Other shapes
--     — `{decision}`, `(rounded)`, `((circle))`, `([stadium])`, `{{hexagon}}`,
--     `[(cylinder)]`, `[[subroutine]]`, `[/parallelogram/]`, `>asymmetric]` — are
--     otherwise taken literally, which splits a node (`B{x}` ≠ `B`) and breaks the
--     graph. normalize_shapes() rewrites them all to `[label]`.
--
--   * sequenceDiagram: it knows `participant [... as ...]` and message arrows, but
--     chokes on `actor`, `Note`, and blocks (`alt`/`else`/`opt`/`loop`/...).
--     normalize_sequence() maps `actor`→`participant`, turns notes and block
--     conditions into self-message annotations (so their text survives), flattens
--     block bodies, and folds wrapped continuation lines back onto their label.
--     The flow renders; visual branching/note boxes don't (the binary has none).
--
-- Work is async (vim.system) and cached by block content, so typing stays
-- responsive and a diagram is only re-rendered when its text actually changes.

local M = {}

local ns = vim.api.nvim_create_namespace("mermaid_ascii")

local config = {
  filetypes = { "markdown", "pandoc", "rmd", "quarto", "markdown.pandoc" },
  -- Resolved in setup(): PATH first, then the go install location.
  bin = nil,
  ascii = false,    -- true => plain ASCII (-a); false => extended box-drawing
  padding_x = nil,  -- horizontal gap between nodes (mermaid-ascii -x)
  padding_y = nil,  -- vertical gap between nodes (mermaid-ascii -y)
  debounce = 150,   -- ms to wait after a change before re-rendering
  enabled = true,   -- render by default on matching buffers
}

-- content-hash -> rendered lines (table) on success, or `false` on failure.
local cache = {}
-- content-hash -> true while a render is in flight (de-dupes spawns).
local pending = {}
-- buffer -> false to disable rendering for that buffer.
local buf_enabled = {}
-- buffer -> debounce timer.
local timers = {}

local function is_target(buf)
  if buf_enabled[buf] == false then return false end
  return vim.tbl_contains(config.filetypes, vim.bo[buf].filetype)
end

---Locate every ```mermaid fenced block.
---@param lines string[]
---@return table[] blocks { open, close, indent, body } (0-based line numbers)
local function find_blocks(lines)
  local blocks = {}
  local i = 1
  while i <= #lines do
    local indent, ticks, info = lines[i]:match("^(%s*)(```+)%s*(.*)$")
    if ticks then
      local lang = vim.trim(info):match("^([%w_+-]+)")
      local j, body, closed = i + 1, {}, false
      while j <= #lines do
        local _, close_ticks = lines[j]:match("^(%s*)(```+)%s*$")
        if close_ticks and #close_ticks >= #ticks then
          closed = true
          break
        end
        body[#body + 1] = lines[j]
        j = j + 1
      end
      if lang == "mermaid" then
        blocks[#blocks + 1] = {
          open = i - 1,
          close = (closed and j or #lines) - 1,
          indent = #indent,
          body = body,
        }
      end
      i = (closed and j or #lines) + 1
    else
      i = i + 1
    end
  end
  return blocks
end

-- Node-shape rewrites: { lua pattern capturing (id)(label), replacement }.
-- Ordered so compound delimiters (`((`, `([`, `{{`, ...) are tried before the
-- single-char ones they contain, otherwise `B((x))` would match `(...)` first.
local shape_subs = {
  { "([%w_]+)%(%((.-)%)%)", "%1[%2]" }, -- ((circle))
  { "([%w_]+)%(%[(.-)%]%)", "%1[%2]" }, -- ([stadium])
  { "([%w_]+)%[%((.-)%)%]", "%1[%2]" }, -- [(cylinder)]
  { "([%w_]+)%[%[(.-)%]%]", "%1[%2]" }, -- [[subroutine]]
  { "([%w_]+){{(.-)}}", "%1[%2]" },     -- {{hexagon}}
  { "([%w_]+)%[/(.-)/%]", "%1[%2]" },   -- [/parallelogram/]
  { "([%w_]+)%[\\(.-)\\%]", "%1[%2]" }, -- [\trapezoid\]
  { "([%w_]+){(.-)}", "%1[%2]" },       -- {decision}
  { "([%w_]+)%((.-)%)", "%1[%2]" },     -- (rounded)
  { "([%w_]+)>(.-)%]", "%1[%2]" },      -- >asymmetric]
}

---Rewrite mermaid node shapes the binary can't parse into `[label]` form.
---@param body string[]
---@return string[]
local function normalize_shapes(body)
  local out = {}
  for _, line in ipairs(body) do
    for _, s in ipairs(shape_subs) do line = line:gsub(s[1], s[2]) end
    out[#out + 1] = line
  end
  return out
end

-- The binary's sequence parser only knows `participant [... as ...]` and message
-- arrows. These keywords open statements it rejects outright; block keywords are
-- flattened (their body messages kept) while their condition text is preserved as
-- a self-message annotation so nothing is silently lost.
local seq_block_kw = {
  alt = true, ["else"] = true, opt = true, loop = true, par = true,
  ["and"] = true, rect = true, ["end"] = true, critical = true,
  ["break"] = true, activate = true, deactivate = true, autonumber = true,
  box = true,
}
local seq_stmt_kw = { participant = true, actor = true, note = true }
for k in pairs(seq_block_kw) do seq_stmt_kw[k] = true end

-- A physical line starts a new statement if it leads with a known keyword or
-- contains a message arrow (`->`, `-->>`, `-x`, `-)`, ...). Anything else is a
-- continuation of the previous label (mermaid uses <br/>, but pasted diagrams
-- often wrap mid-label onto a bare line).
local function seq_is_stmt(line)
  local t = vim.trim(line)
  if t == "" then return false end
  local kw = t:match("^(%a+)")
  if kw and seq_stmt_kw[kw:lower()] then return true end
  return t:find("%-%-?[>x%)]") ~= nil
end

---Rewrite a sequenceDiagram into the subset the binary understands.
---@param body string[]
---@return string[]
local function normalize_sequence(body)
  -- 1. fold wrapped continuation lines back onto their statement.
  local joined = {}
  for _, line in ipairs(body) do
    if vim.trim(line) == "" then
      -- drop blank lines
    elseif #joined == 0 or seq_is_stmt(line) then
      joined[#joined + 1] = line
    else
      joined[#joined] = joined[#joined] .. " " .. vim.trim(line)
    end
  end

  -- sender of the next real message at or after index i (for placing block labels).
  local function next_actor(from)
    for k = from, #joined do
      local a = vim.trim(joined[k]):match("^([%w_]+)%s*%-%-?[>x%)]")
      if a then return a end
    end
  end

  -- 2. rewrite each statement into something the binary accepts.
  local out, last = {}, nil
  for i, line in ipairs(joined) do
    local indent = line:match("^(%s*)")
    local rest = vim.trim(line)
    local kw = (rest:match("^(%a+)") or ""):lower()

    if kw == "actor" then -- actor X  ->  participant X
      out[#out + 1] = indent .. "participant " .. vim.trim(rest:sub(6))
      last = rest:match("^actor%s+([%w_]+)")
    elseif kw == "participant" then
      out[#out + 1] = line
      last = rest:match("^participant%s+([%w_]+)")
    elseif kw == "note" then -- preserve note text as a self-message
      local who, text = rest:match("^[Nn]ote%s+%a+%s+of%s+([%w_]+)%s*:%s*(.*)$")
      if not who then who, text = rest:match("^[Nn]ote%s+over%s+([%w_]+)[^:]*:%s*(.*)$") end
      who = who or last
      if who then
        out[#out + 1] = indent .. who .. "->>" .. who .. ": " .. (text or "")
        last = who
      end
    elseif seq_block_kw[kw] then -- flatten block; keep condition as annotation
      local cond = vim.trim(rest:sub(#kw + 1)):gsub("^%[(.*)%]$", "%1")
      local who = next_actor(i + 1) or last
      if cond ~= "" and who then
        out[#out + 1] = indent .. who .. "->>" .. who .. ": [" .. kw .. "] " .. cond
      end
      -- end/activate/deactivate/autonumber/rect/box with no condition: dropped.
    else
      out[#out + 1] = line
      last = rest:match("^([%w_]+)%s*%-%-?[>x%)]") or last
    end
  end
  return out
end

---Rewrite a block into the dialect the binary understands, by diagram type.
---@param body string[]
---@return string[]
local function preprocess(body)
  local first = ""
  for _, line in ipairs(body) do
    if vim.trim(line) ~= "" then first = vim.trim(line) break end
  end
  if first:match("^graph%f[%s]") or first:match("^flowchart%f[%s]") then
    return normalize_shapes(body)
  elseif first:match("^sequenceDiagram") then
    return normalize_sequence(body)
  end
  return body
end

---Split rendered stdout into lines, trimming trailing blanks.
---@param stdout string
---@return string[]
local function split_lines(stdout)
  local out = {}
  for line in (stdout .. "\n"):gmatch("(.-)\n") do
    out[#out + 1] = line
  end
  while #out > 0 and out[#out]:match("^%s*$") do
    out[#out] = nil
  end
  return out
end

---Attach the rendered diagram as virtual lines below the block.
---@param buf integer
---@param block table
---@param rendered string[]
local function draw(buf, block, rendered)
  local pad = string.rep(" ", block.indent)
  local virt = {}
  for _, line in ipairs(rendered) do
    virt[#virt + 1] = { { pad .. line, "MermaidAscii" } }
  end
  vim.api.nvim_buf_set_extmark(buf, ns, block.close, 0, {
    virt_lines = virt,
    virt_lines_above = false,
  })
end

---Spawn mermaid-ascii for one block; cache the result and re-render.
---@param buf integer
---@param key string
---@param body string[]
local function request(buf, key, body)
  if pending[key] then return end
  pending[key] = true

  local cmd = { config.bin, "-f", "-" }
  if config.ascii then table.insert(cmd, "-a") end
  if config.padding_x then vim.list_extend(cmd, { "-x", tostring(config.padding_x) }) end
  if config.padding_y then vim.list_extend(cmd, { "-y", tostring(config.padding_y) }) end

  local stdin = table.concat(preprocess(body), "\n")
  vim.system(cmd, { stdin = stdin, text = true }, function(res)
    pending[key] = nil
    -- Exit code is unreliable (some unsupported diagrams still exit 0), so also
    -- check for the binary's fatal log line and require non-empty output.
    local fatal = res.stderr and res.stderr:find("level=fatal") ~= nil
    local stdout = res.stdout or ""
    if res.code == 0 and not fatal and vim.trim(stdout) ~= "" then
      cache[key] = split_lines(stdout)
    else
      cache[key] = false
    end
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then M.render(buf) end
    end)
  end)
end

---Render every mermaid block in the buffer.
---@param buf? integer
function M.render(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not config.bin or not is_target(buf) then return end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for _, block in ipairs(find_blocks(lines)) do
    local key = table.concat(block.body, "\n")
    local cached = cache[key]
    if cached == nil then
      request(buf, key, block.body) -- not seen yet: render async
    elseif cached then
      draw(buf, block, cached)      -- success: show it
    end
    -- cached == false: unsupported diagram, leave the source as-is.
  end
end

---Debounced render, to avoid spawning a process on every keystroke.
---@param buf integer
local function schedule_render(buf)
  if timers[buf] then
    timers[buf]:stop()
    timers[buf]:close()
    timers[buf] = nil
  end
  local timer = vim.uv.new_timer()
  timers[buf] = timer
  if not timer then return end
  timer:start(config.debounce, 0, function()
    timer:stop()
    timer:close()
    timers[buf] = nil
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then M.render(buf) end
    end)
  end)
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  if not config.bin then
    if vim.fn.executable("mermaid-ascii") == 1 then
      config.bin = "mermaid-ascii"
    else
      local go_bin = vim.fs.joinpath(vim.fn.expand("$HOME"), "go", "bin", "mermaid-ascii")
      if vim.fn.executable(go_bin) == 1 then config.bin = go_bin end
    end
  end

  vim.api.nvim_set_hl(0, "MermaidAscii", { link = "Comment", default = true })

  local augroup = vim.api.nvim_create_augroup("MermaidAscii", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = config.filetypes,
    callback = function(ev)
      if buf_enabled[ev.buf] == nil then buf_enabled[ev.buf] = config.enabled end
      M.render(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
    group = augroup,
    callback = function(ev) M.render(ev.buf) end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    callback = function(ev) schedule_render(ev.buf) end,
  })

  vim.api.nvim_create_user_command("MermaidAsciiToggle", function()
    local buf = vim.api.nvim_get_current_buf()
    buf_enabled[buf] = not (buf_enabled[buf] ~= false)
    M.render(buf)
    vim.notify("Mermaid ASCII " .. (buf_enabled[buf] and "on" or "off"),
      vim.log.levels.INFO, { title = "MermaidAscii" })
  end, { desc = "Toggle inline mermaid ASCII rendering for this buffer" })

  vim.api.nvim_create_user_command("MermaidAsciiRender", function()
    cache = {} -- force a fresh render
    M.render(0)
  end, { desc = "Re-render mermaid ASCII diagrams (clears cache)" })
end

return M
