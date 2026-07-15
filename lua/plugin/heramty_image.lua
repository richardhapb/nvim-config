-- HeraMty images — inline rendering of note attachments plus clipboard paste.
--
-- Rendering uses the kitty graphics protocol with unicode placeholders
-- (U+10EEEE cells carrying the image id in the foreground color and the
-- row/column in combining diacritics). That is the only placement style that
-- both scrolls with the buffer (placeholders live in extmark virt_lines) and
-- survives tmux, where classic cursor placements are not tracked. Works in
-- Ghostty/kitty/WezTerm; inside tmux `allow-passthrough on` is required.
--
-- Attachment bytes are fetched through the backend's S3 proxy
-- (`GET /api/v1/attachments/<id>/download`, bearer auth) — the API never
-- exposes the raw S3 object key, so the proxy is the only addressable route.
-- Files are cached under stdpath('cache')/heramty and converted to PNG with
-- `sips` (macOS) or ImageMagick when needed: kitty file transmission is
-- PNG-only, and the web frontend uploads compressed JPEGs.

local M = {}

M.ns = vim.api.nvim_create_namespace('heramty_image')

-- Injected by heramty.setup(): { api = fun, get_key = fun, config = table }.
M.ctx = nil

M.opts = {
  enabled = true,
  max_cols = 60,
  max_rows = 24,
}

local LEVELS = vim.log.levels

local function notify(msg, level)
  vim.notify(msg, level or LEVELS.INFO, { title = 'HeraMty' })
end

-- ── pure helpers (unit-tested in tests/heramty_image_spec.lua) ───────────────

---Extract markdown image links pointing at heramty attachments. Both the
---root-relative form the web UI writes (`/api/attachments/<id>/download`)
---and absolute URLs are accepted; plain `[file](…)` links are not images.
---@param lines string[]
---@return { lnum: integer, id: string, alt: string }[]
function M.extract_images(lines)
  local out = {}
  for lnum, line in ipairs(lines) do
    local init = 1
    while true do
      local s, e, alt, url = line:find('!%[([^%]]*)%]%(([^%)]+)%)', init)
      if not s then break end
      local id = url:match('attachments/([0-9a-fA-F%-]+)/download')
      if id then
        table.insert(out, { lnum = lnum, id = id, alt = alt })
      end
      init = e + 1
    end
  end
  return out
end

---Parse width/height out of a PNG file header.
---@param path string
---@return integer? width, integer? height
function M.png_dims(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local head = f:read(24) or ''
  f:close()
  if #head < 24 or head:sub(1, 8) ~= '\137PNG\r\n\26\n' then return nil end
  local function be32(i)
    local a, b, c, d = head:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return be32(17), be32(21)
end

---Wrap a terminal escape sequence for tmux passthrough when inside tmux.
---@param seq string
---@return string
function M.tmux_wrap(seq)
  if not vim.env.TMUX then return seq end
  return '\027Ptmux;' .. seq:gsub('\027', '\027\027') .. '\027\\'
end

---Fit an image (pixels) into the cell grid preserving aspect ratio.
---@return integer cols, integer rows
function M.fit(img_w, img_h, cell_w, cell_h, max_cols, max_rows)
  local cols = math.min(max_cols, math.max(1, math.ceil(img_w / cell_w)))
  local rows = math.max(1, math.ceil(cols * cell_w * img_h / img_w / cell_h))
  if rows > max_rows then
    rows = max_rows
    cols = math.max(1, math.floor(rows * cell_h * img_w / img_h / cell_w))
  end
  return cols, rows
end

-- Row/column diacritics from the kitty graphics spec: the Nth entry marks
-- placeholder row/column N.
local DIACRITICS = vim.split(
  '0305,030D,030E,0310,0312,033D,033E,033F,0346,034A,034B,034C,0350,0351,0352,0357,035B,0363,0364,0365,0366,0367,0368,0369,036A,036B,036C,036D,036E,036F,0483,0484,0485,0486,0487,0592,0593,0594,0595,0597,0598,0599,059C,059D,059E,059F,05A0,05A1,05A8,05A9,05AB,05AC,05AF,05C4,0610,0611,0612,0613,0614,0615,0616,0617,0657,0658,0659,065A,065B,065D,065E,06D6,06D7,06D8,06D9,06DA,06DB,06DC,06DF,06E0,06E1,06E2,06E4,06E7,06E8,06EB,06EC,0730,0732,0733,0735,0736,073A,073D,073F,0740,0741,0743,0745,0747,0749,074A,07EB,07EC,07ED,07EE,07EF,07F0,07F1,07F3,0816,0817,0818,0819,081B,081C,081D,081E,081F,0820,0821,0822,0823,0825,0826,0827,0829,082A,082B,082C,082D,0951,0953,0954,0F82,0F83,0F86,0F87,135D,135E,135F,17DD,193A,1A17,1A75,1A76,1A77,1A78,1A79,1A7A,1A7B,1A7C,1B6B,1B6D,1B6E,1B6F,1B70,1B71,1B72,1B73,1CD0,1CD1,1CD2,1CDA,1CDB,1CE0,1DC0,1DC1,1DC3,1DC4,1DC5,1DC6,1DC7,1DC8,1DC9,1DCB,1DCC,1DD1,1DD2,1DD3,1DD4,1DD5,1DD6,1DD7,1DD8,1DD9,1DDA,1DDB,1DDC,1DDD,1DDE,1DDF,1DE0,1DE1,1DE2,1DE3,1DE4,1DE5,1DE6,1DFE,20D0,20D1,20D4,20D5,20D6,20D7,20DB,20DC,20E1,20E7,20E9,20F0,2CEF,2CF0,2CF1,2DE0,2DE1,2DE2,2DE3,2DE4,2DE5,2DE6,2DE7,2DE8,2DE9,2DEA,2DEB,2DEC,2DED,2DEE,2DEF,2DF0,2DF1,2DF2,2DF3,2DF4,2DF5,2DF6,2DF7,2DF8,2DF9,2DFA,2DFB,2DFC,2DFD,2DFE,2DFF,A66F,A67C,A67D,A6F0,A6F1,A8E0,A8E1,A8E2,A8E3,A8E4,A8E5,A8E6,A8E7,A8E8,A8E9,A8EA,A8EB,A8EC,A8ED,A8EE,A8EF,A8F0,A8F1,AAB0,AAB2,AAB3,AAB7,AAB8,AABE,AABF,AAC1,FE20,FE21,FE22,FE23,FE24,FE25,FE26,10A0F,10A38,1D185,1D186,1D187,1D188,1D189,1D1AA,1D1AB,1D1AC,1D1AD,1D242,1D243,1D244',
  ',')

local PLACEHOLDER = vim.fn.nr2char(0x10EEEE)

-- Lazy diacritic char cache: dia[n] is the combining char for row/column n.
local dia = setmetatable({}, {
  __index = function(t, k)
    local hex = DIACRITICS[k]
    local ch = hex and vim.fn.nr2char(tonumber(hex, 16)) or ''
    rawset(t, k, ch)
    return ch
  end,
})

---Placeholder text for one image row: every cell tags its row and column so
---the terminal can rebuild the grid regardless of how nvim redraws it.
---@param row integer 1-based image row
---@param cols integer
---@return string
function M.placeholder_line(row, cols)
  local parts = {}
  for col = 1, cols do
    parts[col] = PLACEHOLDER .. dia[row] .. dia[col]
  end
  return table.concat(parts)
end

-- ── terminal I/O ─────────────────────────────────────────────────────────────

local function term_write(seq)
  vim.fn.chansend(vim.v.stderr, M.tmux_wrap(seq))
end

-- Terminal cell size in pixels, via TIOCGWINSZ. tmux ≥3.4 forwards the
-- client's pixel size; when the terminal doesn't report one, fall back to a
-- plausible cell so images still render (only their size is approximate).
local cdef_done = false
local function cell_size()
  local ok, ffi = pcall(require, 'ffi')
  if ok then
    if not cdef_done then
      pcall(ffi.cdef, [[
        typedef struct { unsigned short ws_row, ws_col, ws_xpixel, ws_ypixel; } hmt_winsize;
        int ioctl(int, unsigned long, ...);
      ]])
      cdef_done = true
    end
    local TIOCGWINSZ = vim.fn.has('mac') == 1 and 0x40087468 or 0x5413
    local ws = ffi.new('hmt_winsize')
    for _, fd in ipairs({ 1, 2, 0 }) do
      if ffi.C.ioctl(fd, TIOCGWINSZ, ws) == 0
          and ws.ws_xpixel > 0 and ws.ws_col > 0 and ws.ws_row > 0 then
        return ws.ws_xpixel / ws.ws_col, ws.ws_ypixel / ws.ws_row
      end
    end
  end
  return 9, 18
end

-- attachment uuid -> terminal image id (small ints double as fg colors).
local ids = {}
local next_id = 0

local function id_for(att_id)
  if not ids[att_id] then
    next_id = next_id + 1
    ids[att_id] = next_id
  end
  return ids[att_id]
end

---The placeholder fg color IS the image id (24-bit, since termguicolors).
local function hl_for(img_id)
  local name = 'HeramtyImage' .. img_id
  vim.api.nvim_set_hl(0, name, { fg = string.format('#%06x', img_id) })
  return name
end

local transmitted = {}

---Transmit the PNG by file path and create a virtual (U=1) placement of
---rows×cols that the placeholder cells map onto.
local function transmit(img_id, path, cols, rows)
  if transmitted[img_id] then
    -- Drop the old data+placements so re-renders don't accumulate.
    term_write(('\027_Gq=2,a=d,d=I,i=%d\027\\'):format(img_id))
  end
  term_write(('\027_Gq=2,a=T,f=100,t=f,i=%d,U=1,r=%d,c=%d;%s\027\\')
    :format(img_id, rows, cols, vim.base64.encode(path)))
  transmitted[img_id] = true
end

-- ── fetching (backend S3 proxy → cache → PNG) ───────────────────────────────

local function cache_dir()
  local dir = vim.fs.joinpath(vim.fn.stdpath('cache'), 'heramty')
  vim.fn.mkdir(dir, 'p')
  return dir
end

local function is_png(path)
  local f = io.open(path, 'rb')
  if not f then return false end
  local head = f:read(8)
  f:close()
  return head == '\137PNG\r\n\26\n'
end

---Convert any image format to PNG. Tries sips (ships with macOS), then
---ImageMagick. cb(ok) on the main loop.
local function to_png(raw, png, cb)
  local cmds = {
    { 'sips', '-s', 'format', 'png', raw, '--out', png },
    { 'magick', raw, png },
    { 'convert', raw, png },
  }
  local function try(i)
    local cmd = cmds[i]
    if not cmd then return cb(false) end
    if vim.fn.executable(cmd[1]) ~= 1 then return try(i + 1) end
    vim.system(cmd, {}, function(res)
      vim.schedule(function()
        if res.code == 0 then cb(true) else try(i + 1) end
      end)
    end)
  end
  try(1)
end

-- attachment id -> callback list while a download is in flight, so the same
-- image referenced twice is fetched once.
local pending = {}

---Fetch attachment bytes into the cache as PNG. cb(png_path?) on main loop.
---@param att_id string
---@param cb fun(png_path: string?)
local function fetch(att_id, cb)
  local png = vim.fs.joinpath(cache_dir(), att_id .. '.png')
  if vim.uv.fs_stat(png) then return cb(png) end

  if pending[att_id] then
    return table.insert(pending[att_id], cb)
  end
  pending[att_id] = { cb }

  local function done(path)
    local cbs = pending[att_id]
    pending[att_id] = nil
    for _, f in ipairs(cbs) do f(path) end
  end

  local key = M.ctx.get_key()
  if not key then return done(nil) end

  local raw = png .. '.raw'
  local url = M.ctx.config.url .. '/api/v1/attachments/' .. att_id .. '/download'
  vim.system(
    { 'curl', '-sS', '-f', '-o', raw, '-H', 'Authorization: Bearer ' .. key, url },
    { text = true },
    function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          notify('Image download failed: ' .. vim.trim(res.stderr or ''), LEVELS.WARN)
          return done(nil)
        end
        if is_png(raw) then
          os.rename(raw, png)
          return done(png)
        end
        to_png(raw, png, function(ok)
          os.remove(raw)
          if not ok then
            notify('Could not convert attachment to PNG (need sips or ImageMagick)', LEVELS.WARN)
            return done(nil)
          end
          done(png)
        end)
      end)
    end)
end

-- ── rendering ────────────────────────────────────────────────────────────────

---Render every attachment image link in the buffer as virt_lines below the
---link. Safe to call repeatedly: the namespace is cleared first and the
---download cache prevents re-fetching.
---@param buf integer
function M.render(buf)
  if not (M.ctx and M.opts.enabled) then return end
  if not vim.api.nvim_buf_is_valid(buf) then return end

  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local imgs = M.extract_images(lines)
  if #imgs == 0 then return end

  local cell_w, cell_h = cell_size()
  local win = vim.fn.bufwinid(buf)
  local win_cols = win ~= -1 and vim.api.nvim_win_get_width(win) or vim.o.columns
  local max_cols = math.max(8, math.min(M.opts.max_cols, win_cols - 6))

  for _, img in ipairs(imgs) do
    -- Anchor an extmark now so the placement survives edits made while the
    -- download is in flight.
    local mark = vim.api.nvim_buf_set_extmark(buf, M.ns, img.lnum - 1, 0, {})
    fetch(img.id, function(png)
      if not png or not vim.api.nvim_buf_is_valid(buf) then return end
      local w, h = M.png_dims(png)
      if not w or w == 0 or h == 0 then return end

      local cols, rows = M.fit(w, h, cell_w, cell_h, max_cols, M.opts.max_rows)
      local img_id = id_for(img.id)
      transmit(img_id, png, cols, rows)

      local hl = hl_for(img_id)
      local virt = {}
      for r = 1, rows do
        virt[r] = { { M.placeholder_line(r, cols), hl } }
      end
      local pos = vim.api.nvim_buf_get_extmark_by_id(buf, M.ns, mark, {})
      if #pos == 0 then return end
      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, pos[1], 0,
        { id = mark, virt_lines = virt })
    end)
  end
end

---@param buf integer
function M.clear(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  end
end

function M.toggle()
  M.opts.enabled = not M.opts.enabled
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.b[b].heramty_note_id then
      if M.opts.enabled then M.render(b) else M.clear(b) end
    end
  end
  notify('Images ' .. (M.opts.enabled and 'enabled' or 'disabled'))
end

-- ── clipboard paste ──────────────────────────────────────────────────────────

---Dump the clipboard image (if any) as PNG at `path`. cb(ok) on main loop.
local function clipboard_image(path, cb)
  local candidates
  if vim.fn.has('mac') == 1 then
    if vim.fn.executable('pngpaste') == 1 then
      candidates = { { 'pngpaste', path } }
    else
      -- No pngpaste dependency: AppleScript can coerce the clipboard to PNG.
      local script = table.concat({
        ('set f to open for access POSIX file %q with write permission'):format(path),
        'set eof of f to 0',
        'write (the clipboard as «class PNGf») to f',
        'close access f',
      }, '\n')
      candidates = { { 'osascript', '-e', script } }
    end
  else
    local q = vim.fn.shellescape(path)
    candidates = {
      { 'sh', '-c', 'wl-paste -t image/png > ' .. q },
      { 'sh', '-c', 'xclip -selection clipboard -t image/png -o > ' .. q },
    }
  end

  local function try(i)
    local cmd = candidates[i]
    if not cmd then return cb(false) end
    vim.system(cmd, {}, function(res)
      vim.schedule(function()
        local st = vim.uv.fs_stat(path)
        if res.code == 0 and st and st.size > 0 then return cb(true) end
        os.remove(path)
        try(i + 1)
      end)
    end)
  end
  try(1)
end

---Paste the clipboard image into the current note: upload it as an
---attachment, insert the same root-relative markdown link the web UI writes
---(so both clients resolve it), and render it.
function M.paste()
  local buf = vim.api.nvim_get_current_buf()
  local note_id = vim.b[buf].heramty_note_id
  if not note_id then
    return notify('Not a HeraMty note buffer', LEVELS.WARN)
  end

  local tmp = vim.fs.joinpath(cache_dir(), ('clip-%d.png'):format(vim.uv.os_getpid()))
  clipboard_image(tmp, function(ok)
    if not ok then
      return notify('No image in the clipboard', LEVELS.WARN)
    end
    local name = os.date('pasted-%Y%m%d-%H%M%S.png')
    notify('Uploading image…')
    M.ctx.api('POST', '/notes/' .. note_id .. '/attachments',
      { form = { path = tmp, mime = 'image/png', filename = name } },
      function(err, att)
        if err or type(att) ~= 'table' or not att.id then
          return notify('Upload failed: ' .. (err or '?'), LEVELS.ERROR)
        end
        -- Seed the cache so rendering doesn't immediately re-download.
        vim.uv.fs_copyfile(tmp, vim.fs.joinpath(cache_dir(), att.id .. '.png'))
        os.remove(tmp)

        if vim.api.nvim_buf_is_valid(buf) then
          local link = ('![%s](/api/attachments/%s/download)'):format(att.filename, att.id)
          -- Below the cursor line, unless the user moved on mid-upload.
          local row = vim.api.nvim_get_current_buf() == buf
              and vim.api.nvim_win_get_cursor(0)[1]
              or vim.api.nvim_buf_line_count(buf)
          vim.api.nvim_buf_set_lines(buf, row, row, false, { link })
          M.render(buf)
        end
        notify('Image attached — :w to save the note')
      end)
  end)
end

-- ── setup ────────────────────────────────────────────────────────────────────

---@param ctx { api: function, get_key: function, config: table }
function M.setup(ctx)
  M.ctx = ctx
  M.opts = vim.tbl_extend('force', M.opts, ctx.config.images or {})

  -- Free the terminal-side image memory we allocated.
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('HeramtyImage', { clear = true }),
    callback = function()
      for _, img_id in pairs(ids) do
        term_write(('\027_Gq=2,a=d,d=I,i=%d\027\\'):format(img_id))
      end
    end,
  })
end

return M
