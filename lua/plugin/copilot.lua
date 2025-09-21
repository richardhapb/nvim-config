local M = {}

M.copilot_handler = nil
M.socket_chan = nil

-- This avoids LSP attachment to the buffer, but Tree-sitter marks the syntax.
vim.filetype.add({
  extension = {
    ["copilot-chat.md"] = "copilot-chat-cli",
  },
  filename = {
    [".copilot-chat"] = "copilot-chat-cli",
  },
})
vim.treesitter.language.register("markdown", "copilot-chat-cli")


---Get the Copilot's buffer if it exists; otherwise, create one.
---@return integer
local function get_copilot_buffer()
  local bufs = vim.api.nvim_list_bufs()

  for _, buf in ipairs(bufs) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match(".*/(.*)$") == "copilot-chat-cli" and vim.api.nvim_buf_is_valid(buf) then
      return buf
    end
  end

  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, "copilot-chat-cli")
  vim.api.nvim_set_option_value("filetype", "copilot-chat-cli", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf }) -- Automatically discard buffer on close
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
  "",
  "=========== COPILOT ===========",
  "",
}

M.setup = function()
  -- Request a message commit
  vim.api.nvim_create_user_command("CopilotCommit", function()
    vim.fn.jobstart({ "copilot-chat", "commit" }, {
      env = { ["RUST_LOG"] = "copilot_chat=trace" },
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

  -- Clear the saved chat
  vim.api.nvim_create_user_command("CopilotClear", function()
    vim.fn.jobstart({ "copilot-chat", "clear" }, {
      cwd = vim.fn.getcwd(),
      env = { ["RUST_LOG"] = "copilot_chat=trace" },
      stdin = "null",
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, stdout)
        vim.schedule(function()
          vim.api.nvim_buf_set_lines(M.copilot_buffer, 0, -1, false, {})
          vim.notify(vim.fn.join(stdout, " "), vim.log.levels.INFO)
        end)
      end,
      on_stderr = function(_, stderr)
        vim.print(stderr)
      end,
    })
  end, {})

  -- Send a prompt to copilot
  vim.api.nvim_create_user_command("CopilotSend", function(args)
    if args.range > 0 then
      M.temp_float_prompt(args.line1, args.line2)
    else
      M.temp_float_prompt(nil, nil)
    end
  end, { range = 1 })

  -- Restart the handler to open a new connection
  vim.api.nvim_create_user_command("CopilotRestart", function()
    if M.copilot_handler then
      vim.fn.chanclose(M.copilot_handler, "stdin")
      M.copilot_handler = nil
    end
  end, {})

  -- Open the copilot's buffer
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

    M.copilot_buffer = get_copilot_buffer()
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
    vim.api.nvim_set_option_value("filetype", "copilot-chat", { buf = buf })

    local keys = { '<CR>', '<Esc>', 'q' }
    for _, key in ipairs(keys) do
      vim.keymap.set('n', key, function()
        vim.cmd("q!")
      end, { noremap = true, buffer = buf })
    end
  end, {})

  vim.keymap.set("n", "<leader>am", ":CopilotCommit<CR>", { silent = true })
  vim.keymap.set("n", "<leader>ab", ":CopilotBuffer<CR>", { silent = true })
  vim.keymap.set("n", "<leader>ax", ":CopilotClear<CR>", { silent = true })
  vim.keymap.set("n", "<leader>ar", ":CopilotRestart<CR>", { silent = true })
  vim.keymap.set({ "x", "n" }, "<leader>av", ":CopilotSend<CR>", { silent = true })
end

---Custom prompt in a floating window with context
---@param start integer?
---@param last integer?
function M.temp_float_prompt(start, last)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "copilot-chat-cli", { buf = buf })

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

function M.handle_output(data)
  if data and #data > 0 then
    for i, line in ipairs(data) do
      if not vim.api.nvim_buf_is_valid(M.copilot_buffer) then
        break
      end
      local last_line = vim.api.nvim_buf_line_count(M.copilot_buffer) - 1
      if i > 1 then
        -- Insert new lines if exists
        vim.api.nvim_buf_set_lines(M.copilot_buffer, -1, -1, false, { line })
      else
        local last_line_content = vim.api.nvim_buf_get_lines(M.copilot_buffer, -2, -1, false)
        local last_column = 0
        if #last_line_content > 0 then
          last_column = #last_line_content[1]
        end
        vim.api.nvim_buf_set_text(M.copilot_buffer, last_line, last_column, last_line, last_column, { line })
      end

      -- Auto-scroll to bottom if the cursor is in the last line
      local _, curln = unpack(vim.fn.getcurpos())
      if curln >= last_line then
        local win_ids = vim.fn.win_findbuf(M.copilot_buffer)
        for _, win_id in ipairs(win_ids) do
          vim.api.nvim_win_set_cursor(win_id, { last_line + 1, 0 })
        end
      end
    end
  end
end

---Send a prompt to copilot and include the context
---@param content string
---@param start integer?
---@param last integer?
function M.send_to_copilot(content, start, last)
  local range = ""
  local file = vim.fn.expand("%:.")
  if start and last then
    range = ":" .. tostring(start) .. "-" .. tostring(last)
  end
  vim.cmd("CopilotBuffer")
  local line_count = vim.api.nvim_buf_line_count(M.copilot_buffer)
  if line_count > 0 then
    vim.api.nvim_buf_set_lines(M.copilot_buffer, line_count, -1, false, COPILOT_HEADER)
  else
    vim.api.nvim_buf_set_lines(M.copilot_buffer, 0, -1, false, COPILOT_HEADER)
  end

  local win_ids = vim.fn.win_findbuf(M.copilot_buffer)
  for _, win_id in ipairs(win_ids) do
    vim.api.nvim_win_set_cursor(win_id, { vim.api.nvim_buf_line_count(M.copilot_buffer), 0 })
  end

  local function get_transport()
    if not M.copilot_handler then
      -- Create a temporary server to find an available port
      local available_port = 4000
      local server = vim.loop.new_tcp()
      if server then
        server:bind('127.0.0.1', 0) -- Port 0 lets the OS assign an available port
        available_port = server:getsockname().port
        server:close()
      end
      M.copilot_handler_port = available_port

      M.copilot_handler = vim.fn.jobstart(
        { "copilot-chat", "tcp", "--port", tostring(available_port), "--model", "claude-3.7-sonnet" },
        {
          cwd = vim.fn.getcwd(),
          env = { ["RUST_LOG"] = "copilot_chat=trace" },
          on_stdout = vim.schedule_wrap(function(_, data) M.handle_output(data) end),
          on_stderr = function(_, err) vim.print("STDERR:", err) end,
        })
      vim.uv.sleep(1000) -- Ensure the server is ready
    end

    -- The key issue: We need to create a new socket connection for each message
    -- Close the previous socket if it exists
    if M.socket_chan then
      vim.fn.chanclose(M.socket_chan)
      M.socket_chan = nil
    end

    -- Create a new socket connection
    local port = M.copilot_handler_port or 4000 -- Fallback to 4000 if not set
    M.socket_chan = vim.fn.sockconnect("tcp", "127.0.0.1:" .. port, {
      on_data = function(_, data)
        M.handle_output(data)
      end,
    })

    return function(msg)
      msg = file .. range .. "@" .. msg
      vim.fn.chansend(M.socket_chan, msg)
      -- No longer close the handler - only close the socket when needed
    end
  end

  -- Create a new handler only if one doesn't exist yet
  local diagnostics = M.get_diagnostics(start, last)
  if diagnostics and #diagnostics > 0 then
    content = content .. "\n\nThe diagnostics of the Buffer are: \n" .. M.generate_diagnostics(diagnostics)
  end

  local transport = get_transport()
  transport(content)
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
