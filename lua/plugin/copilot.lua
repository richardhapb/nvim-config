local M = {}

---Get the Copilot's buffer if it exists; otherwise, create one.
---@return integer
local function get_copilot_buffer()
  local bufs = vim.api.nvim_list_bufs()

  for _, buf in ipairs(bufs) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match(".*/(.*)$") == "copilot-chat" and vim.api.nvim_buf_is_valid(buf) then
      return buf
    end
  end

  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, "copilot-chat")
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  return buf
end

---Encode a string so it is safe for use as a filename
---@param path string
---@return string
local function encode_path(path)
  local encode, _ = path:gsub("[^%w]", function(c)
    return string.format("%%%02X", string.byte(c))
  end)

  return encode
end

M.copilot_buffer = get_copilot_buffer()

COPILOT_HEADER = {
  "",
  "=========== COPILOT ===========",
  "",
}

M.setup = function()
  vim.api.nvim_create_user_command("CopilotCommit", function()
    vim.fn.jobstart({ "copilot-chat", "commit" }, {
      cwd = vim.fn.getcwd(),
      stdin = "null",
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(code, stdout)
        if code ~= 0 then
          vim.cmd("G commit")
          local buf = vim.api.nvim_get_current_buf()
          vim.api.nvim_buf_set_lines(buf, 0, 0, false, stdout)
        end
      end,
      on_stderr = function(_, stderr)
        vim.print(stderr)
      end,
    })
  end, {})

  vim.api.nvim_create_user_command("CopilotSend", function(args)
    if args.range > 0 then
      M.temp_float_prompt(args.line1, args.line2)
    else
      M.temp_float_prompt(nil, nil)
    end
  end, { range = 1 })

  vim.api.nvim_create_user_command("CopilotBuffer", function()
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.5)

    local row = vim.o.lines / 2 - height / 2
    local col = vim.o.columns / 2 - width / 2

    local win_config = {
      relative = 'editor',
      border = 'rounded',
      focusable = true,
      row = row,
      col = col,
      width = width,
      height = height,
      style = 'minimal',
      title = "Copilot-Chat"
    }

    local buf = M.copilot_buffer
    local cwd = vim.fn.getcwd()

    local temp_file = vim.fs.joinpath(vim.fn.expand("$HOME"), ".cache", "copilot-chat", encode_path(cwd)) .. ".json"
    if vim.fn.filereadable(temp_file) == 1 then
      local raw = vim.fn.readfile(temp_file)
      local ok, chat = pcall(vim.json.decode, table.concat(raw, "\n"))
      if ok and chat.messages then
        local names = { system = "COPILOT", user = "RICHARD" }
        local lines = {}
        for _, message in ipairs(chat.messages) do
          table.insert(lines, "")
          table.insert(lines, "=========== " .. (names[message.role] or "") .. " ===========")
          table.insert(lines, "")
          for _, line in ipairs(vim.split(message.content, "\n", { plain = true })) do
            table.insert(lines, line)
          end
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      end
    end

    local win = vim.api.nvim_open_win(buf, true, win_config)
    vim.api.nvim_set_option_value("wrap", true, { win = 0 })
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

    local keys = { '<CR>', '<Esc>', 'q' }
    for _, key in ipairs(keys) do
      vim.keymap.set('n', key, function() vim.cmd("q!") end, { noremap = true, buffer = buf })
    end
  end, {})

  vim.keymap.set("n", "<leader>am", ":CopilotCommit<CR>", { silent = true })
  vim.keymap.set("n", "<leader>ab", ":CopilotBuffer<CR>", { silent = true })
  vim.keymap.set({ "x", "n" }, "<leader>av", ":CopilotSend<CR>", { silent = true })
end

---Custom prompt in a floating window with context
---@param start integer?
---@param last integer?
function M.temp_float_prompt(start, last)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.2)

  local row = -height - 2
  local col = 0

  local win_config = {
    relative = 'cursor',
    border = 'rounded',
    focusable = true,
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    title = "Custom prompt"
  }

  local win = vim.api.nvim_open_win(buf, true, win_config)

  vim.wo[win].wrap = true
  vim.cmd 'startinsert'

  local function send_prompt()
    local prompt = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
    vim.cmd 'stopinsert'
    vim.cmd 'q!'
    if prompt and prompt ~= '' then
      M.send_to_copilot(prompt, start, last)
    end
  end

  vim.keymap.set('n', '<CR>', send_prompt, { buffer = buf })
  vim.keymap.set('i', '<C-s>', send_prompt, { buffer = buf })

  vim.keymap.set('n', 'q', "<CMD>q!<CR>", { buffer = buf, silent = true })
end

---Send a prompt to copilot and include the context
---@param content string
---@param start integer?
---@param last integer?
function M.send_to_copilot(content, start, last)
  local range = ""
  local file = vim.fn.expand("%:.")
  if start and last then
    -- Copilot expects the `file:line1-line2` format or just `file` for the full file.
    range = ":" .. tostring(start) .. "-" .. tostring(last)
  end

  local job = vim.fn.jobstart({ "copilot-chat", "--files", file .. range }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = vim.schedule_wrap(function(_, stdout)
      -- TODO: Recover previous chats if exists
      vim.api.nvim_buf_set_lines(M.copilot_buffer, -1, -1, false, COPILOT_HEADER)
      vim.api.nvim_buf_set_lines(M.copilot_buffer, -1, -1, false, stdout)

      vim.cmd("CopilotBuffer")
    end),
    on_stderr = vim.schedule_wrap(function(_, stderr)
      vim.notify(vim.fn.join(stderr, "\n"), vim.log.levels.ERROR)
    end)
  })

  local diagnostics = M.get_diagnostics(start, last)

  if diagnostics and #diagnostics > 0 then
    content = content .. "\n\nThe diagnostics of the Buffer are: \n" .. M.generate_diagnostics(diagnostics)
  end

  vim.fn.chansend(job, content)
  vim.fn.chanclose(job, "stdin")
end

---@class Diagnostic
---@field content string
---@field severity lsp.DiagnosticSeverity
---@field start_line integer
---@field end_line integer

---Extract the diagnostic from a range
---@param start integer
---@param last integer
function M.get_diagnostics(start, last)
  local diagnostics = vim.diagnostic.get(0)
  ---@type Diagnostic[]
  local range_diagnostics = {}
  local severity = {
    [1] = 'ERROR',
    [2] = 'WARNING',
    [3] = 'INFORMATION',
    [4] = 'HINT',
  }

  for _, diagnostic in ipairs(diagnostics) do
    local lnum = diagnostic.lnum + 1
    if (not start or lnum >= start) and (not last or lnum <= last) then
      table.insert(range_diagnostics, {
        severity = severity[diagnostic.severity],
        content = diagnostic.message,
        start_line = lnum,
        end_line = diagnostic.end_lnum and diagnostic.end_lnum + 1 or lnum,
      })
    end
  end

  return #range_diagnostics > 0 and range_diagnostics or nil
end

---Generate the diagnostics as a string
---@param diagnostics Diagnostic[]
---@return string
function M.generate_diagnostics(diagnostics)
  local out = {}
  for _, diagnostic in ipairs(diagnostics) do
    table.insert(
      out,
      string.format(
        '%s line=%d-%d: %s',
        diagnostic.severity,
        diagnostic.start_line,
        diagnostic.end_line,
        diagnostic.content
      )
    )
  end
  return table.concat(out, '\n')
end

return M
