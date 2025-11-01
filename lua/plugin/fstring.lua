local utils = require 'functions.utils'

LOGGER_REGEX = "^%s*logger%.[^%(]+%("
QUOTE_REGEX = "f([\"\'])"
ELEMENT_REGEX = "({[^{}]-})"

---@param quote string
---@return string
local function build_fstring_pattern(quote)
  return "f(" .. quote .. "[^" .. quote .. "]+" .. quote .. ")"
end

--- Capture the type of the fstring, for example
--- {some_float:.2f} returns "f"
---@param element string
---@return string
local function resolve_type(element)
  local t = element:match(":%.?%d?([srdf])")
  local d = element:match(":%.(%d)f")
  t = t or "s"
  if d and t == "f" then
    t = "." .. d .. t
  end
  return t
end

---@param element string
---@return string
local function sanitize_element(element)
  local sanitized = element:gsub("!.?", ""):gsub(":%.%df", "")
  return sanitized
end

---@param fstring string
---@return string Transformed string
---@return integer Changes made
local function transform_fstring(fstring)
  local changes = 0
  local transformed = fstring
  for element in fstring:gmatch(ELEMENT_REGEX) do
    changes = changes + 1

    local typ = resolve_type(element)
    local safe = utils.safe_pattern(element)
    transformed = transformed:gsub(safe, "%%" .. typ, 1)
    element = sanitize_element(element)
    transformed = transformed .. ", " .. element:sub(2, #element - 1)
  end
  return transformed, changes
end

---Transform the fstring in Python logger according to rule G004 from Ruff
---logger.info(f"Some stuff: {stuff}") -> logger.info("Some stuff, %s", stuff)
local function fix_fstring()
  local cline, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local begin = cline
  local found = false

  for i = 0, 10 do
    local head = math.max(1, cline - i)
    if lines[head]:find(LOGGER_REGEX) then
      found = true
      begin = head
      break
    end
  end

  if not found then
    vim.notify("Logger statement not found", vim.log.levels.WARN)
    return
  end

  local last_line = math.min(#lines, begin + 10)

  local parentheses = 0
  local fstring_content = ""
  local quotes_captured = false
  local index = begin

  local start_col_fstring = 0
  local end_col_fstring = #lines[begin]

  local captured_lines = {}
  for i, line in ipairs(vim.list_slice(lines, begin, last_line)) do
    -- The first line should match at least one parenthesis
    for _ in line:gmatch("%(") do parentheses = parentheses + 1 end
    for _ in line:gmatch("%)") do parentheses = parentheses - 1 end

    -- For now only parse one line, it is very uncommon more than
    -- one line for a fstring in the logger, but for now I capture just it.
    if not quotes_captured then
      local quote = line:match(QUOTE_REGEX)
      if quote then
        local pattern = build_fstring_pattern(quote)
        fstring_content = line:match(pattern)

        start_col_fstring = line:find(pattern) or 0
        end_col_fstring = start_col_fstring + #fstring_content

        start_col_fstring = start_col_fstring - 1 -- Capture the "f"
        index = index + i - 1
      end
    end

    table.insert(captured_lines, line)

    if parentheses == 0 then
      -- End of the logger statement
      break
    end
  end

  if fstring_content == "" then
    vim.notify("f-string not found", vim.log.levels.WARN)
    return
  end

  local transformed, changes = transform_fstring(fstring_content)

  --- Sub - 1 to capture the `f`
  vim.api.nvim_buf_set_text(0, index - 1, start_col_fstring, index - 1, end_col_fstring, { transformed })
  vim.notify(changes .. " changes made", vim.log.levels.INFO)
end

local function setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("FString", { clear = true }),
    pattern = "python",
    callback = function()
      vim.api.nvim_create_user_command("FixFString",
        fix_fstring,
        {}
      )
      vim.keymap.set("n", "<leader>F", fix_fstring)
    end
  })
end

return {
  setup = setup
}
