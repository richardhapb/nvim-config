-- Unit tests for the pure helpers in plugin/heramty_image.
-- Run with:  nvim --headless -l tests/heramty_image_spec.lua
-- Exits non-zero on the first failed assertion.

local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local config = vim.fs.dirname(here)
package.path = vim.fs.joinpath(config, 'lua', '?.lua') .. ';' .. package.path

local img = require('plugin.heramty_image')

local checks = 0
local function eq(got, want, what)
  checks = checks + 1
  if not vim.deep_equal(got, want) then
    io.stderr:write(('FAIL %s\n  want: %s\n  got:  %s\n')
      :format(what, vim.inspect(want), vim.inspect(got)))
    os.exit(1)
  end
end

-- ── extract_images ────────────────────────────────────────────────────────────

local uuid = '0198c9b2-1111-4222-8333-abcdefabcdef'
local links = img.extract_images({
  'plain text, no links',
  -- Root-relative form written by the web UI and by paste.
  ('![shot.png](/api/attachments/%s/download)'):format(uuid),
  -- Absolute URL form must resolve too.
  ('before ![x](https://heramty.richardhapb.com/api/v1/attachments/%s/download) after'):format(uuid),
  -- Non-image attachment links (no `!`) are not rendered.
  ('[doc.pdf](/api/attachments/%s/download)'):format(uuid),
  -- Image links to elsewhere are ignored.
  '![ext](https://example.com/cat.png)',
  -- Two images on one line.
  ('![a](/api/attachments/%s/download) ![b](/api/attachments/%s/download)'):format(uuid, uuid),
})
eq(#links, 4, 'number of attachment image links')
eq(links[1], { lnum = 2, id = uuid, alt = 'shot.png' }, 'root-relative link')
eq(links[2].lnum, 3, 'absolute link line')
eq(links[2].id, uuid, 'absolute link id')
eq({ links[3].lnum, links[4].lnum }, { 6, 6 }, 'two links on one line')

-- ── png_dims ─────────────────────────────────────────────────────────────────

local function be32(n)
  return string.char(
    math.floor(n / 2 ^ 24) % 256, math.floor(n / 2 ^ 16) % 256,
    math.floor(n / 2 ^ 8) % 256, n % 256)
end

local tmp = vim.fn.tempname()
local f = assert(io.open(tmp, 'wb'))
f:write('\137PNG\r\n\26\n' .. be32(13) .. 'IHDR' .. be32(1800) .. be32(1201))
f:close()
eq({ img.png_dims(tmp) }, { 1800, 1201 }, 'png dimensions')
os.remove(tmp)

local nf = assert(io.open(tmp, 'wb'))
nf:write('\255\216\255\224 not a png, jpeg-ish header padding')
nf:close()
eq(img.png_dims(tmp), nil, 'non-png returns nil')
os.remove(tmp)

-- ── tmux_wrap ────────────────────────────────────────────────────────────────

local seq = '\027_Gq=2,a=T,i=1;Zm9v\027\\'
vim.env.TMUX = nil
eq(img.tmux_wrap(seq), seq, 'no tmux, no wrapping')
vim.env.TMUX = '/tmp/tmux-1/default,1,0'
eq(img.tmux_wrap(seq),
  '\027Ptmux;\027\027_Gq=2,a=T,i=1;Zm9v\027\027\\\027\\',
  'tmux passthrough doubles every ESC')
vim.env.TMUX = nil

-- ── fit ──────────────────────────────────────────────────────────────────────

-- 800x600 image, 10x20 cells: width-bound at 40 cols -> 15 rows keeps aspect.
eq({ img.fit(800, 600, 10, 20, 40, 24) }, { 40, 15 }, 'width-bound fit')
-- Tall image clamps to max rows and narrows to preserve aspect.
local cols, rows = img.fit(600, 2400, 10, 20, 40, 24)
eq(rows, 24, 'tall image clamps rows')
-- 24 rows * 20px = 480px tall -> 120px wide at 1:4 aspect -> 12 cols.
eq(cols, 12, 'tall image narrows to keep aspect')
-- Tiny image never collapses to zero cells.
eq({ img.fit(4, 4, 10, 20, 40, 24) }, { 1, 1 }, 'tiny image minimum 1x1')

-- ── placeholder_line ─────────────────────────────────────────────────────────

-- Row 2, 3 cols: every cell is U+10EEEE + row diacritic (2nd = U+030D)
-- + column diacritic (0x305, 0x30D, 0x30E for cols 1..3).
local line = img.placeholder_line(2, 3)
local expect = table.concat({
  vim.fn.nr2char(0x10EEEE) .. vim.fn.nr2char(0x30D) .. vim.fn.nr2char(0x305),
  vim.fn.nr2char(0x10EEEE) .. vim.fn.nr2char(0x30D) .. vim.fn.nr2char(0x30D),
  vim.fn.nr2char(0x10EEEE) .. vim.fn.nr2char(0x30D) .. vim.fn.nr2char(0x30E),
})
eq(line, expect, 'placeholder row/column diacritics')
-- Each cell must render one column wide (combining marks are zero-width).
eq(vim.fn.strwidth(line), 3, 'placeholder line cell width')

print(('OK — %d checks passed'):format(checks))
