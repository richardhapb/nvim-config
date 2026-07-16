-- Unit tests for the pure helpers in plugin/heramty.
-- Run with:  nvim --headless -l tests/heramty_spec.lua
-- Exits non-zero on the first failed assertion.

local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local config = vim.fs.dirname(here)
package.path = vim.fs.joinpath(config, 'lua', '?.lua') .. ';' .. package.path

-- The module requires fzf-lua at load; make the opt package available.
pcall(vim.cmd, 'packadd fzf-lua')

local hmt = require('plugin.heramty')

local checks = 0
local function eq(got, want, what)
  checks = checks + 1
  if not vim.deep_equal(got, want) then
    io.stderr:write(('FAIL %s\n  want: %s\n  got:  %s\n')
      :format(what, vim.inspect(want), vim.inspect(got)))
    os.exit(1)
  end
end

-- ── notes_query (keyset pagination query string) ─────────────────────────────

local q = hmt._notes_query

eq(q({}), 'limit=200', 'default limit, no content, no cursor')
eq(q({ limit = 50 }), 'limit=50', 'custom limit')
eq(q({ include_content = true }), 'limit=200&include_content=true', 'include_content flag')
eq(q({ limit = 100, include_content = true }),
  'limit=100&include_content=true', 'limit + content')

-- Opaque base64 cursors must be percent-encoded (+ / = are reserved in a query
-- value; vim.uri_encode leaves them raw, which would corrupt the cursor).
eq(q({ after = 'a+b/c==' }), 'limit=200&after=a%2Bb%2Fc%3D%3D', 'cursor is url-encoded')

-- A null cursor (JSON `null` -> vim.NIL) or empty string is treated as absent.
eq(q({ after = vim.NIL }), 'limit=200', 'vim.NIL cursor is dropped')
eq(q({ after = '' }), 'limit=200', 'empty cursor is dropped')

print(('ok - %d checks passed'):format(checks))
