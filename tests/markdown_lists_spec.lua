-- Unit tests for the pure helper in plugin/markdown_lists.
-- Run with:  nvim --headless -l tests/markdown_lists_spec.lua
-- Exits non-zero on the first failed assertion.

local here = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local config = vim.fs.dirname(here)
package.path = vim.fs.joinpath(config, 'lua', '?.lua') .. ';' .. package.path

local lists = require('plugin.markdown_lists')
local compute = lists._compute

local checks = 0
local function eq(got, want, what)
  checks = checks + 1
  if not vim.deep_equal(got, want) then
    io.stderr:write(('FAIL %s\n  want: %s\n  got:  %s\n')
      :format(what, vim.inspect(want), vim.inspect(got)))
    os.exit(1)
  end
end

-- Plain prose is untouched -- the default <CR> (autoindent and all) runs.
eq(compute('just some text', 14), nil, 'non-list line is left alone')

-- Continuing a bullet keeps the same marker and indent.
eq(compute('- foo', 5), { kind = 'continue', line = '- foo', new_line = '- ', cursor_col = 2 },
  'unordered bullet continues with the same marker')
eq(compute('  * foo', 7), { kind = 'continue', line = '  * foo', new_line = '  * ', cursor_col = 4 },
  'indented bullet keeps its indent and marker style')

-- An empty item exits the list instead of adding another marker below it.
eq(compute('- ', 2), { kind = 'exit', line = '' }, 'empty bullet exits the list')
eq(compute('  - ', 4), { kind = 'exit', line = '  ' }, 'empty indented bullet exits, indent kept')

-- Ordered lists increment the number, independent of `.` vs `)`.
eq(compute('1. first', 8), { kind = 'continue', line = '1. first', new_line = '2. ', cursor_col = 3 },
  'ordered list increments the number')
eq(compute('9) ninth', 8), { kind = 'continue', line = '9) ninth', new_line = '10) ', cursor_col = 4 },
  'ordered list keeps the `)` punctuation')
eq(compute('1. ', 3), { kind = 'exit', line = '' }, 'empty ordered item exits the list')

-- Checkboxes reset to unchecked on the new line, regardless of prior state.
eq(compute('- [ ] todo', 10), { kind = 'continue', line = '- [ ] todo', new_line = '- [ ] ', cursor_col = 6 },
  'unchecked checkbox continues unchecked')
eq(compute('- [x] done', 10), { kind = 'continue', line = '- [x] done', new_line = '- [ ] ', cursor_col = 6 },
  'checked checkbox continues unchecked')
eq(compute('- [ ] ', 6), { kind = 'exit', line = '' }, 'empty checkbox item exits the list')

-- Splitting mid-item: text after the cursor moves down with the new marker.
eq(compute('- foo bar', 5), { kind = 'continue', line = '- foo', new_line = '-  bar', cursor_col = 2 },
  'text after the cursor is carried onto the continued line')

print(('ok - %d checks passed'):format(checks))
