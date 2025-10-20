-- Configuration Constants
local Config = {
  CELL_MARKER_COLOR = "#A5A5A5",
  CELL_FG_COLOR = "#000000",
  CELL_MARKER = "^# %%%%",
  CELL_MARKER_SIGN = "cell_marker_sign",
  SUPPORTED_FILETYPES = { "*.ipynb", "*.py", "*.r", "*.jl", "*.scala" },
}

-- Cell Data Structure
local Cell = {}
Cell.__index = Cell

function Cell.new(start_line, is_markdown)
  local self = setmetatable({}, Cell)
  self.start = start_line
  self.is_markdown = is_markdown or false
  return self
end

-- Sign Manager for Visual Markers
local SignManager = {}
SignManager.__index = SignManager

function SignManager.new(config)
  local self = setmetatable({}, SignManager)
  self.config = config
  self:initialize_highlight()
  return self
end

function SignManager:initialize_highlight()
  vim.api.nvim_set_hl(0, "cell_marker_hl", {
    bg = self.config.CELL_MARKER_COLOR,
    fg = self.config.CELL_FG_COLOR
  })
  vim.fn.sign_define(self.config.CELL_MARKER_SIGN, { linehl = "cell_marker_hl" })
end

function SignManager:place(bufnr, line)
  vim.fn.sign_place(line, self.config.CELL_MARKER_SIGN, self.config.CELL_MARKER_SIGN, bufnr, {
    lnum = line,
    priority = 10,
    text = "%%",
  })
end

function SignManager:clear(bufnr)
  vim.fn.sign_unplace(self.config.CELL_MARKER_SIGN, { buffer = bufnr })
end

function SignManager:clear_at_line(bufnr, line)
  vim.fn.sign_unplace(self.config.CELL_MARKER_SIGN, { buffer = bufnr, id = line })
end

-- Cell Parser - Finds and Analyzes Cells
local CellParser = {}
CellParser.__index = CellParser

function CellParser.new(config)
  local self = setmetatable({}, CellParser)
  self.config = config
  return self
end

function CellParser:parse_buffer(bufnr)
  local cells = {}
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  for line = 1, total_lines do
    local content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
    if content and content ~= "" and content:find(self.config.CELL_MARKER) then
      local is_markdown = content:find("%[markdown%]") ~= nil
      table.insert(cells, Cell.new(line, is_markdown))
    end
  end

  return cells
end

function CellParser:is_cell_empty(bufnr, start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  local marker_line = lines[1]
  if marker_line and marker_line:match("^%s*" .. self.config.CELL_MARKER:sub(2) .. "[^%s]") then
    return false
  end

  for i = 2, #lines do
    local line = lines[i]
    if line and line:match("%S") and not line:match("^%s*[#%-]") then
      return false
    end
  end

  return true
end

-- Cell Navigator - Handles Cell Selection and Navigation
local CellNavigator = {}
CellNavigator.__index = CellNavigator

function CellNavigator.new(config, parser)
  local self = setmetatable({}, CellNavigator)
  self.config = config
  self.parser = parser
  return self
end

function CellNavigator:get_current_cell_bounds()
  local bufnr = vim.api.nvim_get_current_buf()
  local current_row = vim.api.nvim_win_get_cursor(0)[1]
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  local start_line = self:find_cell_start(bufnr, current_row)
  local end_line = self:find_cell_end(bufnr, current_row, line_count)

  return start_line, end_line
end

function CellNavigator:find_cell_start(bufnr, from_line)
  for line = from_line, 1, -1 do
    local content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
    if content:find(self.config.CELL_MARKER) then
      return line
    end
  end
  return 1
end

function CellNavigator:find_cell_end(bufnr, from_line, line_count)
  for line = from_line + 1, line_count do
    local content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
    if content:find(self.config.CELL_MARKER) then
      return line
    end
  end
  return line_count
end

function CellNavigator:move_to_adjacent_cell(direction_up)
  local start_line, end_line = self:get_current_cell_bounds()

  if direction_up then
    if start_line == 1 then return false end
    vim.api.nvim_win_set_cursor(0, { start_line - 1, 0 })
    return true
  else
    local bufnr = vim.api.nvim_get_current_buf()
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if end_line == line_count then return false end

    vim.api.nvim_win_set_cursor(0, { end_line + 1, 0 })
    start_line, end_line = self:get_current_cell_bounds()
    vim.api.nvim_win_set_cursor(0, { end_line - 1, 0 })
    return true
  end
end

function CellNavigator:get_cell_content(bufnr, start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  return table.concat(lines, "\n")
end

-- Slime Manager
local SlimeManager = {}
SlimeManager.__index = SlimeManager

function SlimeManager.new()
  local self = setmetatable({}, SlimeManager)
  return self
end

function SlimeManager:ensure_repl_running()
  local ft = vim.bo.filetype

  -- Already configured? Done.
  if vim.b.slime_config and vim.b.slime_config.target_pane then
    return true
  end

  local repl_processes = {
    python = "^%%[0-9]*%s[Pp]ython[0-9.]*$",
  }

  local pattern = repl_processes[ft]
  if not pattern then
    return false -- Silent fail for unsupported filetypes
  end

  local repl_commands = {
    python = "ipython --no-autoindent",
    julia = "julia",
    r = "R",
    javascript = "node",
    ruby = "irb",
    lua = "lua",
  }

  local repl_cmd = repl_commands[ft]
  if not repl_cmd then
    vim.notify("No REPL for " .. ft, vim.log.levels.ERROR)
    return false
  end

  -- Try to find existing REPL in last pane
  local handle = io.popen(string.format([[tmux list-panes -F "#{pane_id} #{pane_current_command}"]], pattern))

  if handle then
    local content = vim.trim(handle:read("*a") or "")
    local success = handle:close()
    local pane_id = ""

    for _, line in ipairs(vim.split(content, "\n", { plain = true })) do
      if line:find(pattern) then
        pane_id = vim.split(line, " ", { plain = true })[1] or ""
      end
    end

    if success and pane_id ~= "" then
      vim.b.slime_config = { socket_name = "default", target_pane = pane_id }
      vim.notify("Using pane " .. pane_id, vim.log.levels.INFO)
      return true
    end
  end

  -- Create new REPL
  local result = vim.system({ "tmux", "split-window", "-h", "-d", "-P", "-F", "#{pane_id}" }):wait()
  if result.code ~= 0 then
    return false
  end

  local pane_id = vim.trim(result.stdout)

  -- Source venv if exists
  local venv_path = vim.fn.getcwd() .. "/.venv/bin/activate"
  if vim.fn.filereadable(venv_path) == 1 then
    vim.system({ "tmux", "send-keys", "-t", pane_id, "source .venv/bin/activate", "C-m" }):wait()
    vim.wait(100)
  end

  -- Start REPL
  vim.system({ "tmux", "send-keys", "-t", pane_id, repl_cmd, "C-m" }):wait()
  vim.wait(500)

  vim.b.slime_config = { socket_name = "default", target_pane = pane_id }
  vim.notify("Started " .. repl_cmd, vim.log.levels.INFO)
  return true
end

function SlimeManager:send_lines(start_line, end_line)
  if not self:ensure_repl_running() then
    return false
  end

  -- Get the lines
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local code = table.concat(lines, "\n")

  -- Send to slime
  vim.fn["slime#send"](code .. "\n")

  return true
end

-- Cell Executor - Handles Cell Execution Logic with Slime
local CellExecutor = {}
CellExecutor.__index = CellExecutor

function CellExecutor.new(parser, navigator, slime_manager)
  local self = setmetatable({}, CellExecutor)
  self.parser = parser
  self.navigator = navigator
  self.slime = slime_manager
  return self
end

function CellExecutor:execute_current_cell()
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line, end_line = self.navigator:get_current_cell_bounds()

  if self.parser:is_cell_empty(bufnr, start_line, end_line) then
    vim.notify("Cell is empty", vim.log.levels.WARN)
    return false
  end

  -- Skip the marker line
  if self.slime:send_lines(start_line + 1, end_line - 1) then
    vim.notify("Cell executed", vim.log.levels.INFO)
    return true
  end

  return false
end

function CellExecutor:execute_all_cells()
  local bufnr = vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local cells = self.parser:parse_buffer(bufnr)

  if #cells == 0 then
    vim.notify("No cells found", vim.log.levels.WARN)
    return
  end

  local executed = self:execute_cell_range(bufnr, cells, 1, #cells, line_count)
  vim.notify(string.format("Executed %d code cell(s)", executed), vim.log.levels.INFO)
end

function CellExecutor:execute_until_cursor(include_current)
  local current_row = vim.api.nvim_win_get_cursor(0)[1]
  local bufnr = vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  local cells = self.parser:parse_buffer(bufnr)
  if #cells == 0 then
    vim.notify("No cells found in buffer", vim.log.levels.WARN)
    return
  end

  local last_index = self:find_execution_boundary(cells, current_row, include_current)
  if last_index < 1 then
    vim.notify("No preceding cell to execute", vim.log.levels.WARN)
    return
  end

  local executed = self:execute_cell_range(bufnr, cells, 1, last_index, line_count)
  vim.notify(string.format("Executed %d code cell(s)", executed), vim.log.levels.INFO)
end

function CellExecutor:find_execution_boundary(cells, cursor_row, include_current)
  local index = -1

  for i, cell in ipairs(cells) do
    if cell.start <= cursor_row then
      index = i
    else
      break
    end
  end

  if not include_current and index > 0 then
    local current_cell_start = cells[index].start
    if cursor_row >= current_cell_start then
      index = index - 1
    end
  end

  return index
end

function CellExecutor:execute_cell_range(bufnr, cells, start_idx, end_idx, line_count)
  local config = vim.b.slime_config

  if not config or not config.target_pane then
    vim.notify("No target pane configured", vim.log.levels.ERROR)
    return 0
  end

  local executed = { count = 0 }

  local function execute_next_cell(idx)
    if idx > end_idx then
      vim.schedule(function()
        vim.notify(string.format("Executed %d code cell(s)", executed.count), vim.log.levels.INFO)
      end)
      return
    end

    local cell = cells[idx]
    local cell_end = (cells[idx + 1] and cells[idx + 1].start - 1) or line_count

    if cell.is_markdown then
      execute_next_cell(idx + 1)
      return
    end

    if self.parser:is_cell_empty(bufnr, cell.start, cell_end) then
      vim.schedule(function()
        vim.notify("Skipping empty cell at line " .. cell.start, vim.log.levels.INFO)
      end)
      execute_next_cell(idx + 1)
      return
    end

    -- Send cell
    local success = self.slime:send_lines(cell.start + 1, cell_end)
    if success then
      executed.count = executed.count + 1
    end

    -- Poll tmux pane for In[N]: prompt before continuing
    local max_attempts = 1000 -- 100 seconds max wait
    local attempts = 0

    vim.defer_fn(function()
      local check_prompt
      check_prompt = function()
        attempts = attempts + 1

        if attempts > max_attempts then
          vim.schedule(function()
            vim.notify("Timeout waiting for REPL, continuing anyway", vim.log.levels.WARN)
          end)
          execute_next_cell(idx + 1)
          return
        end

        local result = vim.system({
          "tmux", "capture-pane", "-t", config.target_pane, "-p"
        }):wait()

        if not result or not result.stdout then
          vim.defer_fn(check_prompt, 100)
          return
        end

        local output = result.stdout

        -- Look for IPython prompt in last few lines
        local lines = vim.split(vim.trim(output), "\n")
        local last_line = lines[#lines] or ""

        -- More flexible prompt matching
        if last_line:match("In %[") or last_line:match("In%[") or
            last_line:match(">>>") or last_line:match("%.%.%.") then
          -- Ready for next cell
          execute_next_cell(idx + 1)
        else
          -- Still executing, check again
          vim.defer_fn(check_prompt, 100)
        end
      end
      check_prompt()
    end, 200) -- Give first cell more time
  end

  -- Start execution
  execute_next_cell(start_idx)

  return 0
end

-- Cell Editor - Handles Cell Manipulation
local CellEditor = {}
CellEditor.__index = CellEditor

function CellEditor.new(navigator, sign_manager)
  local self = setmetatable({}, CellEditor)
  self.navigator = navigator
  self.sign_manager = sign_manager
  return self
end

function CellEditor:delete_current_cell()
  local start_line, end_line = self.navigator:get_current_cell_bounds()
  if not start_line or not end_line then return end

  local rows_to_select = end_line - start_line - 1
  vim.api.nvim_win_set_cursor(0, { start_line, 0 })
  vim.cmd("normal!V " .. rows_to_select .. "j")
  vim.cmd "normal!d"
  vim.cmd "normal!k"

  self:refresh_markers()
end

function CellEditor:insert_cell(marker_text)
  local _, end_line = self.navigator:get_current_cell_bounds()
  local bufnr = vim.api.nvim_get_current_buf()

  local insert_line = (end_line ~= 1) and (end_line - 1) or end_line
  vim.api.nvim_win_set_cursor(0, { insert_line, 0 })

  vim.cmd "normal!2o"
  vim.api.nvim_buf_set_lines(bufnr, insert_line, insert_line + 1, false, { marker_text })

  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  self.sign_manager:place(bufnr, current_line - 1)

  vim.cmd "normal!2o"
  vim.cmd "normal!k"

  self:refresh_markers()
end

function CellEditor:refresh_markers()
  -- Bound to main manager's method
end

-- Main Jupyter Manager - Orchestrates Everything
local JupyterManager = {}
JupyterManager.__index = JupyterManager

function JupyterManager.new()
  local self = setmetatable({}, JupyterManager)

  self.config = Config
  self.sign_manager = SignManager.new(self.config)
  self.parser = CellParser.new(self.config)
  self.navigator = CellNavigator.new(self.config, self.parser)
  self.slime_manager = SlimeManager.new()
  self.executor = CellExecutor.new(self.parser, self.navigator, self.slime_manager)
  self.editor = CellEditor.new(self.navigator, self.sign_manager)

  self.editor.refresh_markers = function() self:show_all_markers() end
  self.group = vim.api.nvim_create_augroup("JupyterConfig", { clear = true })

  return self
end

function JupyterManager:show_all_markers()
  local bufnr = vim.api.nvim_get_current_buf()
  self.sign_manager:clear(bufnr)

  local cells = self.parser:parse_buffer(bufnr)
  for _, cell in ipairs(cells) do
    self.sign_manager:place(bufnr, cell.start)
  end
end

function JupyterManager:show_current_marker()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]

  if content and content ~= "" and content:find(self.config.CELL_MARKER) then
    self.sign_manager:place(bufnr, line)
  else
    self.sign_manager:clear_at_line(bufnr, line)
  end
end

function JupyterManager:setup_keymaps()
  local keys = {
    { "<localleader>x", function() self.executor:execute_current_cell() end,        desc = "Execute Cell" },
    { "<localleader>X", function() self.executor:execute_all_cells() end,           desc = "Execute All Cells" },
    { "<localleader>i", function() self.editor:insert_cell("# %%") end,             desc = "Insert Code Cell" },
    { "<localleader>m", function() self.editor:insert_cell("# %% [markdown]") end,  desc = "Insert Markdown Cell" },
    { "<localleader>d", function() self.editor:delete_current_cell() end,           desc = "Delete Cell" },
    { "<localleader>n", function() self.navigator:move_to_adjacent_cell(false) end, desc = "Next Cell" },
    { "<localleader>p", function() self.navigator:move_to_adjacent_cell(true) end,  desc = "Previous Cell" },
    { "<localleader>M", function() self:show_all_markers() end,                     desc = "Reload markers" },
    { "<localleader>v", function() vim.cmd "SlimeSend" end,                         mode = "v",                             desc = "Send Selection" },
    { "<localleader>l", function() vim.cmd "SlimeSend" end,                         desc = "Send Line" },
    { "<localleader>h", function() self.executor:execute_until_cursor(false) end,   desc = "Execute until cursor" },
    { "<localleader>H", function() self.executor:execute_until_cursor(true) end,    desc = "Execute until cursor (include)" },
  }

  for _, key in ipairs(keys) do
    vim.keymap.set(key.mode or "n", key[1], key[2], { desc = key.desc })
  end
end

function JupyterManager:setup_autocommands()
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = self.group,
    pattern = self.config.SUPPORTED_FILETYPES,
    callback = function() vim.schedule(function() self:show_all_markers() end) end,
  })

  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    group = self.group,
    pattern = self.config.SUPPORTED_FILETYPES,
    callback = function() vim.schedule(function() self:show_current_marker() end) end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = self.group,
    callback = function(args)
      if args.file:find('%.ipynb$') then
        vim.bo[args.buf].filetype = "python"
      end
    end
  })

  self:setup_lsp_config()
end

function JupyterManager:setup_lsp_config()
  vim.api.nvim_create_autocmd("LspAttach", {
    pattern = { "*.ipynb" },
    callback = function(e)
      local client = vim.lsp.get_client_by_id(e.data.client_id)
      if not client or client.name ~= "pyright" or not client.settings then
        return
      end

      local pyright_overrides = {
        analysis = {
          typeCheckingMode = "standard",
          diagnosticSeverityOverrides = {
            reportUnusedVariable = "none",
            reportUnusedFunction = "none",
            reportUntypedFunctionDecorator = "none",
            reportConstantRedefinition = "none",
            reportUnnecessaryIsInstance = "none",
            reportUnusedCallResult = "none",
            reportUnusedExpression = "none",
          }
        }
      }

      client.settings.python = vim.tbl_deep_extend('force', client.settings.python, pyright_overrides)
      vim.defer_fn(function()
        client:notify("workspace/didChangeConfiguration", { settings = nil })
      end, 100)
    end,
  })
end

function JupyterManager:setup()
  vim.g.jupytext_fmt = "py:percent"

  vim.g.slime_target = "tmux"
  vim.g.slime_default_config = {
    socket_name = "default",
    target_pane = "{last}",
  }

  vim.g.slime_cell_delimiter = "# %%"
  vim.g.slime_dont_ask_default = 1
  vim.g.slime_bracketed_paste = 1

  self:setup_autocommands()
  self:setup_keymaps()
end

-- Module Export
return {
  setup = function()
    local manager = JupyterManager.new()
    manager:setup()
  end
}
