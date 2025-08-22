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
end

return M
