-- HeraMty — edit your HeraMty notes directly from Neovim over the HTTP API.
--
-- Notes open as `acwrite` scratch buffers named `heramty://<id>/<slug>.md`;
-- plain `:w` PUTs them back (honouring the optimistic lock). Navigation is an
-- fzf-lua picker over every note, labelled `wall/board — title`. `[[…]]`
-- wiki-links follow with <CR>, mirroring the web UI's scoped resolution.
--
-- Auth: `HERAMTY_API_KEY` (an `hmt_live_…` key) from the environment — add it
-- to the `envs` table in `.env.lua`. Base URL defaults to the hosted instance
-- and is overridable with `HERAMTY_URL`.

local M = {}

local fzf = require('fzf-lua')

M.config = {
  url = 'https://heramty.richardhapb.com',
  key_env = 'HERAMTY_API_KEY',
  keymaps = true,
}

-- Session cache: { notes = Note[], walls = Wall[], boards = { [board_id] = Loc } }
-- where Loc = { board_id, board_name, wall_id, wall_name }. Busted on any write.
M.cache = { index = nil }

local LEVELS = vim.log.levels

local function notify(msg, level)
  vim.notify(msg, level or LEVELS.INFO, { title = 'HeraMty' })
end

---@return string?
local function get_key()
  local k = vim.env[M.config.key_env]
  if not k or k == '' then
    notify(('Set %s in .env.lua'):format(M.config.key_env), LEVELS.ERROR)
    return nil
  end
  return k
end

---Slugify a title for the cosmetic part of a buffer name.
---@param s string
---@return string
local function slugify(s)
  local out = (s or ''):lower():gsub('[^%w]+', '-'):gsub('^-+', ''):gsub('-+$', '')
  return out == '' and 'note' or out
end

---@return string uuid v4
local function uuid()
  return (('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'):gsub('[xy]', function(c)
    local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
    return string.format('%x', v)
  end))
end

local WRITE_METHODS = { POST = true, PUT = true, PATCH = true, DELETE = true }

---Async HTTP call against /api/v1. cb(err, data, status, raw).
---@param method string
---@param path string  e.g. "/notes/123"
---@param opts table?  { body = table?, query = string?, _retried = boolean? }
---@param cb fun(err: string?, data: any, status: integer?, raw: string?)
local function api(method, path, opts, cb)
  opts = opts or {}
  local key = get_key()
  if not key then return cb('no api key') end

  local url = M.config.url .. '/api/v1' .. path
  if opts.query then url = url .. '?' .. opts.query end

  local args = {
    'curl', '-sS', '-X', method, url,
    '-H', 'Authorization: Bearer ' .. key,
    '-w', '\n%{http_code}',
  }
  if WRITE_METHODS[method] then
    vim.list_extend(args, { '-H', 'Idempotency-Key: ' .. uuid() })
  end
  local stdin = nil
  if opts.body then
    stdin = vim.json.encode(opts.body)
    vim.list_extend(args, {
      '-H', 'Content-Type: application/json',
      '--data-binary', '@-',
    })
  end

  vim.system(args, { text = true, stdin = stdin }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        return cb('curl failed: ' .. vim.trim(result.stderr or ''))
      end

      local out = result.stdout or ''
      local body, code = out:match('^(.*)\n(%d+)%s*$')
      local status = tonumber(code)
      if not status then
        return cb('malformed response')
      end

      -- Honour rate limiting: back off once, then give up.
      if status == 429 and not opts._retried then
        opts._retried = true
        return vim.defer_fn(function() api(method, path, opts, cb) end, 1000)
      end

      local data = nil
      if body and body ~= '' then
        local ok, decoded = pcall(vim.json.decode, body)
        if ok then data = decoded end
      end

      if status >= 200 and status < 300 then
        return cb(nil, data, status, body)
      end
      cb(('HTTP %d'):format(status), data, status, body)
    end)
  end)
end

---Build (or return cached) the note list + board→location index.
---@param cb fun(index: table)
local function build_index(cb)
  if M.cache.index then return cb(M.cache.index) end

  api('GET', '/walls', {}, function(err, walls)
    if err or type(walls) ~= 'table' then
      return notify('Failed to list walls: ' .. (err or '?'), LEVELS.ERROR)
    end

    local boards = {}

    local function finish()
      api('GET', '/notes', {}, function(e2, notes)
        if e2 or type(notes) ~= 'table' then
          return notify('Failed to list notes: ' .. (e2 or '?'), LEVELS.ERROR)
        end
        M.cache.index = { notes = notes, walls = walls, boards = boards }
        cb(M.cache.index)
      end)
    end

    if #walls == 0 then return finish() end

    local pending = #walls
    for _, w in ipairs(walls) do
      api('GET', '/walls/' .. w.id .. '/boards', {}, function(e, bs)
        if not e and type(bs) == 'table' then
          for _, b in ipairs(bs) do
            boards[b.id] = {
              board_id = b.id,
              board_name = b.name,
              wall_id = w.id,
              wall_name = w.name,
            }
          end
        end
        pending = pending - 1
        if pending == 0 then finish() end
      end)
    end
  end)
end

local function bust_cache()
  M.cache.index = nil
end

-- ── buffers ────────────────────────────────────────────────────────────────

---Find an existing buffer already holding this note.
---@param id string
---@return integer?
local function buf_for_note(id)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.b[b].heramty_note_id == id then
      return b
    end
  end
  return nil
end

---@param buf integer
---@return boolean
local function is_note_buf(buf)
  return vim.b[buf].heramty_note_id ~= nil
end

local function require_note_buf()
  local buf = vim.api.nvim_get_current_buf()
  if not is_note_buf(buf) then
    notify('Not a HeraMty note buffer', LEVELS.WARN)
    return nil
  end
  return buf
end

---Render a note into a reusable `heramty://` buffer and switch to it.
---@param note table  { id, title, content, board_id, updated_at }
local function render_note(note)
  local existing = buf_for_note(note.id)
  local buf = existing or vim.api.nvim_create_buf(true, false)

  if not existing then
    local name = ('heramty://%s/%s.md'):format(note.id, slugify(note.title))
    pcall(vim.api.nvim_buf_set_name, buf, name)
    vim.bo[buf].buftype = 'acwrite'
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = 'markdown'

    vim.api.nvim_create_autocmd('BufWriteCmd', {
      buffer = buf,
      callback = function() M.save(buf) end,
    })

    -- Follow `[[…]]` wiki-links from inside the note.
    vim.keymap.set('n', '<CR>', M.follow_link,
      { buffer = buf, silent = true, desc = 'HeraMty: follow wiki-link' })
    vim.keymap.set('n', 'gf', M.follow_link,
      { buffer = buf, silent = true, desc = 'HeraMty: follow wiki-link' })
  end

  local lines = vim.split(note.content or '', '\n', { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.b[buf].heramty_note_id = note.id
  vim.b[buf].heramty_title = note.title
  vim.b[buf].heramty_updated_at = note.updated_at
  vim.b[buf].heramty_board_id = note.board_id
  local loc = M.cache.index and M.cache.index.boards[note.board_id]
  vim.b[buf].heramty_wall_id = loc and loc.wall_id or nil

  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].modified = false
end

---@param id string
function M.open_note(id)
  local existing = buf_for_note(id)
  if existing then
    return vim.api.nvim_set_current_buf(existing)
  end
  api('GET', '/notes/' .. id, {}, function(err, note)
    if err or not note then
      return notify('Failed to open note: ' .. (err or '?'), LEVELS.ERROR)
    end
    render_note(note)
  end)
end

-- ── save (BufWriteCmd) ───────────────────────────────────────────────────────

---@param buf integer
function M.save(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local id = vim.b[buf].heramty_note_id
  if not id then return end

  local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
  local body = {
    title = vim.b[buf].heramty_title,
    content = content,
    updated_at = vim.b[buf].heramty_updated_at,
  }

  api('PUT', '/notes/' .. id, { body = body }, function(err, note, status, raw)
    if not err and note then
      vim.b[buf].heramty_updated_at = note.updated_at
      vim.bo[buf].modified = false
      bust_cache()
      return notify('Saved')
    end
    -- Optimistic-lock conflict: the server returns 500 "Conflicted note".
    if status == 500 and raw and raw:find('Conflict') then
      return notify(
        'Conflict: note changed on the server. Run :HeramtyDiff to merge, then :w again.',
        LEVELS.ERROR)
    end
    notify('Save failed: ' .. (err or '?'), LEVELS.ERROR)
  end)
end

---Open the server's current version in a diff split so the conflict can be
---merged by hand. Refreshes the buffer's `updated_at` so the next `:w` lands.
function M.diff()
  local buf = require_note_buf()
  if not buf then return end
  local id = vim.b[buf].heramty_note_id

  api('GET', '/notes/' .. id, {}, function(err, note)
    if err or not note then
      return notify('Failed to fetch server version: ' .. (err or '?'), LEVELS.ERROR)
    end

    vim.api.nvim_set_current_buf(buf)
    vim.cmd('diffthis')

    local sbuf = vim.api.nvim_create_buf(false, true)
    pcall(vim.api.nvim_buf_set_name, sbuf, ('heramty://%s/server'):format(id))
    vim.bo[sbuf].buftype = 'nofile'
    vim.bo[sbuf].filetype = 'markdown'
    vim.api.nvim_buf_set_lines(sbuf, 0, -1, false,
      vim.split(note.content or '', '\n', { plain = true }))

    vim.cmd('vsplit')
    vim.api.nvim_set_current_buf(sbuf)
    vim.cmd('diffthis')

    -- Adopt the server's timestamp so a subsequent save isn't rejected again.
    vim.b[buf].heramty_updated_at = note.updated_at
    notify('Server version on the right. Merge into the left buffer, then :w.')
  end)
end

-- ── pickers ──────────────────────────────────────────────────────────────────

local function extract_key(line)
  return line and line:match('\t([^\t]+)$') or nil
end

---Open the note picker (every note, labelled `wall/board — title`).
function M.pick_notes()
  build_index(function(index)
    if #index.notes == 0 then
      return notify('No notes yet — :HeramtyNew to create one', LEVELS.WARN)
    end
    local entries = {}
    local content_map = {}
    for _, n in ipairs(index.notes) do
      local loc = index.boards[n.board_id]
      local label = ('%s/%s — %s'):format(
        loc and loc.wall_name or '?',
        loc and loc.board_name or '?',
        n.title)
      table.insert(entries, label .. '\t' .. n.id)
      content_map[n.id] = n.content or ''
    end

    -- In-memory markdown previewer: the note content is already cached, so no
    -- extra request per selection. Degrades gracefully if the previewer API is
    -- unavailable on this fzf-lua version.
    local previewer
    local ok_b, builtin = pcall(require, 'fzf-lua.previewer.builtin')
    if ok_b then
      local Note = builtin.base:extend()
      function Note:new(o, o2, win)
        Note.super.new(self, o, o2, win)
        setmetatable(self, Note)
        return self
      end

      function Note:populate_preview_buf(entry_str)
        local id = extract_key(entry_str)
        local buf = self:get_tmp_buffer()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false,
          vim.split(content_map[id] or '', '\n', { plain = true }))
        vim.bo[buf].filetype = 'markdown'
        self:set_preview_buf(buf)
        pcall(function() self.win:update_preview_scrollbar() end)
      end

      function Note:gen_winopts()
        return vim.tbl_extend('keep', { wrap = true, number = false }, self.winopts)
      end

      previewer = Note
    end

    fzf.fzf_exec(entries, {
      prompt = 'HeraMty> ',
      previewer = previewer,
      fzf_opts = {
        ['--delimiter'] = '\t',
        ['--with-nth'] = '{1}',
      },
      actions = {
        ['default'] = function(selected)
          local id = extract_key(selected[1])
          if id then M.open_note(id) end
        end,
      },
    })
  end)
end

---Pick a board (drill-down), then call cb(board_id).
---@param cb fun(board_id: string)
local function pick_board(cb)
  build_index(function(index)
    local entries = {}
    for _, loc in pairs(index.boards) do
      table.insert(entries, ('%s/%s'):format(loc.wall_name, loc.board_name) .. '\t' .. loc.board_id)
    end
    table.sort(entries)
    if #entries == 0 then
      return notify('No boards found', LEVELS.WARN)
    end
    fzf.fzf_exec(entries, {
      prompt = 'Board> ',
      fzf_opts = { ['--delimiter'] = '\t', ['--with-nth'] = '{1}' },
      actions = {
        ['default'] = function(selected)
          local id = extract_key(selected[1])
          if id then cb(id) end
        end,
      },
    })
  end)
end

-- ── write commands ────────────────────────────────────────────────────────────

---@param board_id string?  nil ⇒ Inbox
---@param title string?
local function create_note(board_id, title)
  title = title and vim.trim(title) or ''
  if title == '' then
    title = vim.trim(vim.fn.input('Title: '))
  end
  if title == '' then return end

  local body = { title = title, content = '' }
  if board_id then body.board_id = board_id end

  api('POST', '/notes', { body = body }, function(err, note)
    if err or not note then
      return notify('Create failed: ' .. (err or '?'), LEVELS.ERROR)
    end
    bust_cache()
    render_note(note)
    notify('Created "' .. note.title .. '"')
  end)
end

---@param bang boolean  pick a board first instead of dropping into Inbox
---@param title string?
function M.new_note(bang, title)
  if bang then
    pick_board(function(board_id) create_note(board_id, title) end)
  else
    create_note(nil, title)
  end
end

function M.rename()
  local buf = require_note_buf()
  if not buf then return end
  local id = vim.b[buf].heramty_note_id
  local new = vim.trim(vim.fn.input('New title: ', vim.b[buf].heramty_title or ''))
  if new == '' then return end
  vim.b[buf].heramty_title = new
  pcall(vim.api.nvim_buf_set_name, buf, ('heramty://%s/%s.md'):format(id, slugify(new)))
  M.save(buf)
end

function M.move()
  local buf = require_note_buf()
  if not buf then return end
  local id = vim.b[buf].heramty_note_id
  pick_board(function(board_id)
    api('PATCH', '/notes/' .. id .. '/move', { body = { board_id = board_id } }, function(err)
      if err then
        return notify('Move failed: ' .. err, LEVELS.ERROR)
      end
      vim.b[buf].heramty_board_id = board_id
      local loc = M.cache.index and M.cache.index.boards[board_id]
      vim.b[buf].heramty_wall_id = loc and loc.wall_id or nil
      bust_cache()
      notify('Moved')
    end)
  end)
end

function M.delete()
  local buf = require_note_buf()
  if not buf then return end
  local id = vim.b[buf].heramty_note_id
  if vim.fn.confirm('Delete this note?', '&Yes\n&No', 2) ~= 1 then return end
  api('DELETE', '/notes/' .. id, {}, function(err)
    if err then
      return notify('Delete failed: ' .. err, LEVELS.ERROR)
    end
    bust_cache()
    vim.api.nvim_buf_delete(buf, { force = true })
    notify('Deleted')
  end)
end

function M.refresh()
  bust_cache()
  build_index(function() notify('Refreshed') end)
end

-- ── wiki-links ───────────────────────────────────────────────────────────────

---Return the inner text of the `[[…]]` link under the cursor, if any.
---@return string?
local function link_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col('.')
  local init = 1
  while true do
    local s, e, inner = line:find('%[%[([^%[%]\n]+)%]%]', init)
    if not s then return nil end
    if col >= s and col <= e then return inner end
    init = e + 1
  end
end

---Follow a `[[…]]` link, mirroring the web UI: segments read right-to-left
---(note, board, wall), case-insensitive, first match wins, omitted segments
---fall back to the current note's board/wall.
function M.follow_link()
  local inner = link_under_cursor()
  if not inner then
    notify('No [[wiki-link]] under the cursor', LEVELS.WARN)
    return
  end

  local cur_board = vim.b.heramty_board_id
  local cur_wall = vim.b.heramty_wall_id

  local parts = {}
  for _, p in ipairs(vim.split(inner, '/', { plain = true })) do
    p = vim.trim(p)
    if p ~= '' then table.insert(parts, p) end
  end
  if #parts == 0 then return end

  local note_name = parts[#parts]
  local board_name = parts[#parts - 1]
  local wall_name = parts[#parts - 2]

  local function ci_eq(a, b) return a:lower() == b:lower() end

  build_index(function(index)
    local wall_id = cur_wall
    if wall_name then
      wall_id = nil
      for _, w in ipairs(index.walls) do
        if ci_eq(w.name, wall_name) then wall_id = w.id break end
      end
      if not wall_id then return notify('Wall "' .. wall_name .. '" not found', LEVELS.WARN) end
    end
    if not wall_id then return notify('No wall to resolve link', LEVELS.WARN) end

    local board_id = cur_board
    if board_name then
      board_id = nil
      for _, loc in pairs(index.boards) do
        if loc.wall_id == wall_id and ci_eq(loc.board_name, board_name) then
          board_id = loc.board_id
          break
        end
      end
      if not board_id then return notify('Board "' .. board_name .. '" not found', LEVELS.WARN) end
    end
    if not board_id then return notify('No board to resolve link', LEVELS.WARN) end

    for _, n in ipairs(index.notes) do
      if n.board_id == board_id and ci_eq(n.title, note_name) then
        return M.open_note(n.id)
      end
    end
    notify('Note "' .. note_name .. '" not found', LEVELS.WARN)
  end)
end

-- ── setup ──────────────────────────────────────────────────────────────────

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts or {})
  pcall(math.randomseed, os.time())

  local cmd = vim.api.nvim_create_user_command
  cmd('Heramty', function() M.pick_notes() end, { desc = 'HeraMty: open note picker' })
  cmd('HeramtyNew', function(a) M.new_note(a.bang, a.args) end,
    { nargs = '?', bang = true, desc = 'HeraMty: new note (! to pick a board)' })
  cmd('HeramtyRename', function() M.rename() end, { desc = 'HeraMty: rename note' })
  cmd('HeramtyMove', function() M.move() end, { desc = 'HeraMty: move note to a board' })
  cmd('HeramtyDelete', function() M.delete() end, { desc = 'HeraMty: delete note' })
  cmd('HeramtyDiff', function() M.diff() end, { desc = 'HeraMty: diff against server version' })
  cmd('HeramtyRefresh', function() M.refresh() end, { desc = 'HeraMty: refresh cached note list' })

  if M.config.keymaps then
    vim.keymap.set('n', '<leader>nn', M.pick_notes, { silent = true, desc = 'HeraMty notes' })
    vim.keymap.set('n', '<leader>nb', function() M.new_note(false) end,
      { silent = true, desc = 'HeraMty new note' })
  end
end

return M
