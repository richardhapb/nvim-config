local M = {}

local status = {
  full_text = nil,
  text = nil,
  offset = 0,
  buffer = nil
}

---Sort lines of a json object
---@param lines any
local function sort_lines(lines)
  local linenos = {}
  local lineno_result = {}
  local comment_result = {}

  for lineno, _ in pairs(lines) do
    table.insert(linenos, lineno)
  end

  local job = vim.system({ 'sort', '-n', '-r' }, {
    text = true,
    stdin = table.concat(linenos, '\n'),
    stdout = function(_, data)
      if not data then
        return
      end

      for lineno in data:gmatch('[^\r\n]+') do
        table.insert(lineno_result, tonumber(lineno))
        table.insert(comment_result, lines[lineno])
      end
    end
  })

  job:wait()
  return { linenos = lineno_result, comments = comment_result }
end

---Gets text from selection or buffer
---@param range? table
---@param buffer? number
---@return nil
local function get_text(range, buffer)
  if buffer and vim.api.nvim_buf_is_valid(buffer) then
    status.buffer = buffer
  else
    status.buffer = vim.api.nvim_get_current_buf()
  end

  -- Verify if there is a selecion, if there is, use it, else use the whole buffer
  if range and range.count > 1 then
    status.full_text = vim.api.nvim_buf_get_lines(status.buffer, range.line1 - 1, range.line2, false)
    status.text = table.concat(status.full_text, "\n")
    status.offset = range.line1 - 1
  else
    status.full_text = vim.api.nvim_buf_get_lines(status.buffer, 0, -1, false)
    status.text = table.concat(status.full_text, "\n")
  end
end

---Checks values of global status
---@return boolean
local function check_status()
  for _, value in ipairs(status) do
    if not value then
      return false
    end
  end
  return true
end

---Handles the output of stdout
---@param _ any
---@param data table
local function replace_comments(_, data)
  local decoded = vim.json.decode(table.concat(data, "\n"))
  decoded = decoded.choices[1].message.content
  decoded = vim.json.decode(decoded)

  if decoded.single_comments then
    local sorted = sort_lines(decoded.single_comments)

    for lineno_index, comment in ipairs(sorted.comments) do
      local lineno = tonumber(sorted.linenos[lineno_index]) - 1
      local current_line = status.full_text[lineno + 1]
      local col = current_line:find("#") or 0
      col = col + 1

      comment = vim.split(comment, '\n')

      -- If the line is not a comment, add a new line
      -- TODO: if has text before the comment, append the comment to the last comment
      if current_line:find('"""') then
        goto continue
      elseif current_line:find('^[^#]+$') then
        local indent = status.full_text[lineno]:match('^%s*')
        vim.api.nvim_buf_set_lines(status.buffer, status.offset + lineno, status.offset + lineno, false,
          { indent .. '# ' .. table.concat(comment, ' ') })
      else
        vim.api.nvim_buf_set_text(status.buffer, status.offset + lineno, col, status.offset + lineno, -1, comment)
      end
    end
    ::continue::
  end

  if decoded.multiline_comments then
    local sorted = sort_lines(decoded.multiline_comments)

    local last = { lineno = -1, indent = "" }
    for lineno_index, ml_comment in ipairs(sorted.comments) do
      local lineno = tonumber(sorted.linenos[lineno_index]) - 1
      local indent = ""
      if last.lineno == lineno + 1 then
        indent = last.indent
      else
        indent = status.full_text[lineno + 1]:match('^%s*')
      end

      last = { lineno = lineno, indent = indent }

      if status.full_text[lineno + 1]:find('^%s*""".*"""$') then
        ml_comment = '"""' .. ml_comment .. '"""'
      end

      -- If the next line is a closing triple quote, add a new line
      local next_line = lineno + 1
      if status.full_text[lineno + 1]:find('^%s*"""$') then
        next_line = lineno
      end
      vim.api.nvim_buf_set_lines(status.buffer, status.offset + lineno, status.offset + next_line, false,
        { indent .. ml_comment })
    end
  end
end

local function check_spell(range)
  get_text(range)

  if not check_status() then
    return
  end

  if vim.fn.executable("neospeller") == 0 then
    vim.print("neospeller is not installed")
    return
  end

  local command = {"neospeller", "--lang", "python"}

  local job = vim.fn.jobstart( command , {
    stdout_buffered = true,
    on_stdout = replace_comments,
  })

  vim.fn.chansend(job, status.text)
  vim.fn.chanclose(job, "stdin")
end

M.setup = function()
  -- Accept a range
  vim.api.nvim_create_user_command('CheckSpell', function(range)
    check_spell(range)
  end, {
    range = 1,
  })
end

function M.tests()
  local ai_response = [[
{
  \"comments\": {
    \"12\": \"Test Profile.\",
    \"127\": \"Include the profiles added in the fill_profiles_list_with_remaining_matches function, maintaining the same behavior as the view.\",
    \"137\": \"Print debug information to compare with the visual content in the browser and verify the order.\",
    \"138\": \"Profiles online should be in the positions: 7, 57 and 3, 15, 17 according to the get_profiles_display_group_settings function.\",
    \"139\": \"If you change the initial online IDs, another filter may capture them first. Check for this occurrence.\",
    \"141\": \"print('n--------------------------------------------n')\",
    \"142\": \"print(f'profile_list{position}: {profiles_listposition}')\",
    \"143\": \"print(f'Popularity: {profiles_listposition.popularity}')\",
    \"144\": \"print(f'Online: {profiles_listposition.is_online}')\",
    \"145\": \"print(f'Distance: {profiles_listposition.distance}')\",
    \"146\": \"print(f'Is new: {profiles_listposition.is_new}')\",
    \"147\": \"print(f'Has photo: {profiles_listposition.profile_photo is not None}')\",
    \"148\": \"print(f'Group: {profiles_display_group_key}')\",
    \"152\": \"Ensure the profile is in the correct filter group\",
    \"153\": \"Include the profiles added in the fill_profiles_list_with_remaining_matches function\",
    \"16\": \"Install profile examples.\",
    \"160\": \"Ensure the profile is in the correct position\",
    \"167\": \"Ensure the profile is not duplicated\",
    \"177\": \"Ensure that there are no None values in the profiles list\",
    \"180\": \"Ensure that all profiles are displayed in the view\",
    \"183\": \"Ensure that all profiles are displayed in the test\",
    \"186\": \"Ensure that the function returns the correct values\",
    \"19\": \"noqa: S603, S607\",
    \"2\": \"noqa: S404\",
    \"20\": \"noqa: S603, S607\",
    \"204\": \"Test setup\",
    \"213\": \"Test execution\",
    \"216\": \"type: ignore\",
    \"22\": \"noqa: S603, S607\",
    \"224\": \"Ensure the profiles_list is filled with the remaining matches\",
    \"227\": \"Ensure the profiles_list does not contain any duplicate profiles\",
    \"230\": \"Ensure the profiles_list does not contain any None profiles\",
    \"25\": \"noqa: S106\",
    \"29\": \"noqa: PLR0914\",
    \"41\": \"Mock for testing online profiles.\",
    \"44\": \"Mock the fill_profiles_list_with_remaining_matches method to capture the profiles added in the function.\",
    \"47\": \"noqa: ANN001\",
    \"55\": \"Test setup.\",
    \"60\": \"Test execution.\",
    \"70\": \"Profiles already displayed (displayed_profiles_ids_to_exclude in view).\",
    \"71\": \"Profiles displayed from profiles_list.\",
    \"73\": \"Profiles added in the fill_profiles_list_with_remaining_matches function.\",
    \"78\": \"Patch the fill_profiles_list_with_remaining_matches method to capture the profiles added in the function.\",
    \"87\": \"If the last element is a set, it indicates that the fill_profiles_list_with_remaining_matches function was called.\",
    \"91\": \"Verify that each group's positions contain the correct profiles.\"
  },
  \"ml_comments\": {
    \"12\": \"Test Profile.\",
    \"192\": \"Test the fill_profiles_list_with_remaining_matches method.\",
    \"194\": \"Consider the following behaviors:\",
    \"196\": \"- The method should fill the profiles_list with the remaining matches.\",
    \"197\": \"- The method should not return any None profiles.\",
    \"198\": \"- The method should not add any profiles already in the profiles_list.\",
    \"31\": \"Test the order and filtering of profiles, including valid values and next page detection.\",
    \"33\": \"Consider the following behaviors:\",
    \"35\": \"- The order of profiles should follow the preset order in get_profiles_display_group_settings.\",
    \"36\": \"- The filtering of profiles should adhere to the filters in get_profiles_display_group_settings.\",
    \"37\": \"- The profile list should contain only Profile instances, excluding None.\",
    \"38\": \"- The has_more_profiles should be True as there are more profiles to display in this test.\",
    \"39\": \"- The next_page should be an integer as there are more profiles to display in this test.\"
  }
}
      ]]

  local function normalize_text(text)
    for _, char in ipairs { '[', ']', '(', ')', '{', '}', '-' } do
      text = text:gsub('%' .. char, '%%' .. char)
    end

    return text
  end

  -- TESTS
  describe("Buffer and text handling", function()
    local test_buffer = vim.api.nvim_create_buf(false, true)
    local fixture_file = vim.fs.joinpath(vim.fn.stdpath('config'), 'tests-fixtures', 'pyfile.py')
    local file_text = vim.fn.readfile(fixture_file)
    local api_response = { '{ "choices": [ { "message": { "content": "' .. ai_response:gsub('\n', '') .. '" } } ] }' }
    local decoded = vim.json.decode(table.concat(api_response, '\n'))
    decoded = decoded.choices[1].message.content
    decoded = vim.json.decode(decoded)

    vim.api.nvim_buf_set_lines(test_buffer, 0, -1, false, file_text)
    it("Should get correct data", function()
      get_text(nil, test_buffer)

      assert.are_true(type(status.full_text) == 'table')
      assert.are_true(type(status.text) == 'string')
      assert.are_true(type(status.buffer) == 'number')
      assert.are_true(type(status.offset) == 'number')
    end)

    it("Should be sort correctly", function()
      local result = sort_lines(decoded.comments)

      local prev = 99999
      for _, lineno in ipairs(result.linenos) do
        assert.are_true(lineno < prev)
        prev = lineno
      end
    end)

    it("Should get correct lines", function()
      replace_comments(nil, api_response)
      local sorted = sort_lines(decoded.comments)

      for lineno_index, comment in pairs(sorted.comments) do
        local lineno = tonumber(sorted.linenos[lineno_index]) - 1
        local current_line = vim.api.nvim_buf_get_lines(test_buffer, lineno, lineno + 1, false)[1]
        if not current_line:find('"""') then
          assert.are_true(current_line:find("^%s*.*#%s*" .. normalize_text(comment)) ~= nil)
        end
      end
    end)
  end)
end

return M
