local M = {}

---@param char string
---@param line string
---@return string, string
local function split_once(char, line)
  local parts = vim.split(line, char, { plain = true })
  local l = ""
  local r = ""
  for i, part in ipairs(parts) do
    if i == 1 then
      l = part
    else
      if r ~= "" then
        r = r .. char .. part
      else
        r = part
      end
    end
  end

  return l, r
end

---@param char string
---@param text string[]
---@return string[]
local function align(char, text)
  local max = 0
  local lefts = {}
  local rights = {}

  for _, line in ipairs(text) do
    local l, r = split_once(char, line)

    if #l > max then
      max = #l
    end

    table.insert(lefts, l)
    table.insert(rights, r)
  end

  local result = {}

  for i, l in ipairs(lefts) do
    if rights[i] ~= "" then
      if #l < max then
        l = string.format("%s%s", l, string.rep(" ", max - #l))
      end
      table.insert(result, string.format("%s%s%s", l, char, rights[i]))
    else
      table.insert(result, vim.trim(l))
    end
  end

  return result
end

--- Convert to multiline string
---@param lines string[]
---@param max_length integer
---@return string[]
local function to_multiline(lines, max_length)
  local result = {}

  for _, line in ipairs(lines) do
    local new_line = ""
    local indentation = line:match("^%s+") or ""

    line = vim.trim(line)

    for i = 1, #line do
      -- If it does not have space, insert the full word or text
      if not line:find(" ", i, true) and #new_line + #line - i >= max_length then
        table.insert(result, indentation .. new_line .. line:sub(i, #line + 1))
        new_line = ""
        break
      end

      local b = string.byte(line, i)
      local c = string.char(b)
      if #new_line >= max_length then
        local chunks = vim.split(new_line, " ", { plain = true })
        local last_chunk = table.remove(chunks, #chunks)

        -- It is possible that there is only one chunk; if so, the last chunk is the only
        -- one. I need to avoid inserting an empty line.
        if #chunks > 0 then
          table.insert(result, indentation .. vim.fn.join(chunks, " "))
        else
          table.insert(result, indentation .. last_chunk)
          last_chunk = ""
        end
        new_line = last_chunk
      end
      new_line = new_line .. c
    end

    -- Insert the residual text
    if #new_line > 0 then
      table.insert(result, indentation .. new_line)
    end
  end

  return result
end

function M.setup()
  vim.api.nvim_create_user_command('Align',
    function(args)
      local line1 = 1
      local line2 = -1
      if args.range == 0 then
        return
      end

      line1 = args.line1
      line2 = args.line2

      local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
      local new_text = align(vim.trim(args.args), lines)
      vim.api.nvim_buf_set_lines(0, line1 - 1, line2, false, new_text)
    end, {
      nargs = 1,
      range = 1
    })

  vim.api.nvim_create_user_command('Mult',
    function(args)
      local line1 = 1
      local line2 = -1
      if args.range == 0 then
        return
      end

      line1 = args.line1
      line2 = args.line2

      local max_length = 90
      if #args.args > 0 then
        local maybe_int = tonumber(vim.trim(args.args))
        max_length = maybe_int or max_length
      end

      local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
      local new_text = to_multiline(lines, max_length)
      vim.api.nvim_buf_set_lines(0, line1 - 1, line2, false, new_text)
    end, {
      nargs = '?',
      range = 1
    })
end

return M
