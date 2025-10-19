-- Configuration Constants
local Config = {
  CELL_MARKER_COLOR = "#A5A5A5",
  CELL_FG_COLOR = "#000000",
  CELL_MARKER = "^# %%%%",
  CELL_MARKER_SIGN = "cell_marker_sign",
  SUPPORTED_FILETYPES = { "*.ipynb", "*.r", "*.jl", "*.scala" },
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

-- Cache Manager for Cell Boundaries
local CellCache = {}
CellCache.__index = CellCache

function CellCache.new()
  local self = setmetatable({}, CellCache)
  self.cache = {}
  return self
end

function CellCache:get(bufnr)
  return self.cache[bufnr]
end

function CellCache:invalidate(bufnr)
  self.cache[bufnr] = nil
end

function CellCache:update(bufnr, cells)
  self.cache[bufnr] = cells
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

function CellParser.new(config, cache)
  local self = setmetatable({}, CellParser)
  self.config = config
  self.cache = cache
  return self
end

function CellParser:parse_buffer(bufnr)
  local cached = self.cache:get(bufnr)
  if cached then return cached end

  local cells = {}
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  for line = 1, total_lines do
    local content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
    if content and content ~= "" and content:find(self.config.CELL_MARKER) then
      local is_markdown = content:find("%[markdown%]") ~= nil
      table.insert(cells, Cell.new(line, is_markdown))
    end
  end

  self.cache:update(bufnr, cells)
  return cells
end

function CellParser:is_cell_empty(bufnr, start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  -- Check if marker line has content after the marker
  local marker_line = lines[1]
  if marker_line and marker_line:match("^%s*" .. self.config.CELL_MARKER:sub(2) .. "[^%s]") then
    return false
  end

  -- Check remaining lines for non-empty, non-comment content
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

-- Cell Executor - Handles Cell Execution Logic
local CellExecutor = {}
CellExecutor.__index = CellExecutor

function CellExecutor.new(parser, navigator)
  local self = setmetatable({}, CellExecutor)
  self.parser = parser
  self.navigator = navigator
  return self
end

function CellExecutor:execute_until_cursor(include_current)
  local current_row, current_col = unpack(vim.api.nvim_win_get_cursor(0))
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

  vim.api.nvim_win_set_cursor(0, { current_row, current_col })
  vim.notify(string.format("Executed %d code cell(s)", executed), vim.log.levels.INFO, { title = "Jupyter" })
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
  local executed = 0

  for i = start_idx, end_idx do
    local cell = cells[i]
    local cell_end = (cells[i + 1] and cells[i + 1].start - 1) or line_count

    if cell.is_markdown then
      -- Skip markdown cells
    elseif self.parser:is_cell_empty(bufnr, cell.start, cell_end) then
      vim.notify("Skipping empty cell at line " .. cell.start, vim.log.levels.INFO, { title = "Molten" })
    else
      executed = executed + self:execute_single_cell(cell.start)
    end
  end

  return executed
end

function CellExecutor:execute_single_cell(line)
  -- Move cursor to the line AFTER the cell marker, not on the marker itself
  -- Molten needs to be inside the cell content to execute
  vim.api.nvim_win_set_cursor(0, { line + 1, 0 })

  local success, err = pcall(function()
    vim.cmd "MoltenReevaluateCell"
  end)

  if success then
    return 1
  elseif err then
    -- Only show error if it's not the expected "Not in a cell" message
    if not err:match("Not in a cell") then
      vim.notify("Error executing cell at line " .. line .. ": " .. err, vim.log.levels.ERROR)
    end
  end

  return 0
end

-- Cell Editor - Handles Cell Manipulation
local CellEditor = {}
CellEditor.__index = CellEditor

function CellEditor.new(navigator, sign_manager, cache)
  local self = setmetatable({}, CellEditor)
  self.navigator = navigator
  self.sign_manager = sign_manager
  self.cache = cache
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

  local bufnr = vim.api.nvim_get_current_buf()
  self.cache:invalidate(bufnr)
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

  self.cache:invalidate(bufnr)
  self:refresh_markers()
end

function CellEditor:refresh_markers()
  -- This will be bound to the main manager's method
end

-- Main Jupyter Manager - Orchestrates Everything
local JupyterManager = {}
JupyterManager.__index = JupyterManager

function JupyterManager.new()
  local self = setmetatable({}, JupyterManager)

  self.config = Config
  self.cache = CellCache.new()
  self.sign_manager = SignManager.new(self.config)
  self.parser = CellParser.new(self.config, self.cache)
  self.navigator = CellNavigator.new(self.config, self.parser)
  self.executor = CellExecutor.new(self.parser, self.navigator)
  self.editor = CellEditor.new(self.navigator, self.sign_manager, self.cache)

  -- Bind refresh method
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
    { "<localleader>x", function() vim.cmd "MoltenReevaluateCell" end,              desc = "Execute Cell" },
    { "<localleader>X", function() vim.cmd "MoltenReevaluateAll" end,               desc = "Execute All Cells" },
    { "<localleader>i", function() self.editor:insert_cell("# %%") end,             desc = "Insert Code Cell" },
    { "<localleader>m", function() self.editor:insert_cell("# %% [markdown]") end,  desc = "Insert Markdown Cell" },
    { "<localleader>d", function() self.editor:delete_current_cell() end,           desc = "Delete Cell" },
    { "<localleader>n", function() self.navigator:move_to_adjacent_cell(false) end, desc = "Next Cell" },
    { "<localleader>p", function() self.navigator:move_to_adjacent_cell(true) end,  desc = "Previous Cell" },
    { "<localleader>M", function() self:show_all_markers() end,                     desc = "Reload markers" },
    {
      "<localleader>v",
      function()
        vim.cmd.normal(""); vim.cmd "MoltenEvaluateVisual"
      end,
      mode = "v",
      desc = "Send"
    },
    { "<localleader>l", function() vim.cmd "MoltenEvaluateLine" end,              desc = "Send Line" },
    { "<localleader>h", function() self.executor:execute_until_cursor(false) end, desc = "Execute until cursor" },
    { "<localleader>H", function() self.executor:execute_until_cursor(true) end,  desc = "Execute until cursor (include)" },
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
        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(client_data)
            local client = vim.lsp.get_client_by_id(client_data.data.client_id)
            if client and client.name == 'jsonls' then
              client.stop(true)
            end
          end
        })
      end
    end
  })

  self:setup_molten_integration()
  self:setup_lsp_config()
end

function JupyterManager:setup_molten_integration()
  local init_molten_buffer = function(e)
    vim.schedule(function()
      local kernels = vim.fn.MoltenAvailableKernels()
      local kernel_name = self:detect_kernel(e.file, kernels)

      if kernel_name and vim.tbl_contains(kernels, kernel_name) then
        vim.notify("Activating kernel " .. kernel_name, vim.log.levels.INFO, { title = "Molten" })
        vim.cmd(("MoltenInit %s"):format(kernel_name))
      end
      vim.cmd("MoltenImportOutput")
    end)
  end

  vim.api.nvim_create_autocmd("BufAdd", {
    group = self.group,
    pattern = { "*.ipynb" },
    callback = init_molten_buffer,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = self.group,
    pattern = { "*.ipynb" },
    callback = function(e)
      if vim.api.nvim_get_vvar("vim_did_enter") ~= 1 then
        init_molten_buffer(e)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = self.group,
    pattern = { "*.ipynb" },
    callback = function()
      if require("molten.status").initialized() == "Molten" then
        vim.cmd("MoltenExportOutput!")
      end
    end,
  })
end

function JupyterManager:parse_pyvenv_cfg(venv, available_kernels)
  local kernel = string.match(venv, "/.+/(.+)")

  if venv then
    local pyenv_path = vim.fs.joinpath(venv, "pyvenv.cfg")
    if vim.fn.filereadable(pyenv_path) then
      local file = io.open(pyenv_path, "r")
      if file then
        local content = file:read("a")
        file:close()
        for _, line in ipairs(vim.split(content, "\n", { plain = true })) do
          local env = line:match("prompt = (%S+)")
          if env then
            kernel = env
          end
        end
      end
    end

    if kernel and vim.tbl_contains(available_kernels, kernel) then
      return kernel
    end
  end
  return nil
end

function JupyterManager:get_current_env(available_kernels)
  local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
  local env = self:parse_pyvenv_cfg(venv, available_kernels)

  if env then
    return env
  end

  if venv then
    local kernel = string.match(venv, "/.+/(.+)")
    if kernel and vim.tbl_contains(available_kernels, kernel) then
      return kernel
    end
  end
end

function JupyterManager:detect_kernel(filepath, available_kernels)
  local kernel = self:get_current_env(available_kernels)

  if kernel then
    return kernel
  end

  local ok, metadata = pcall(function()
    local content = io.open(filepath, "r"):read("a")
    return vim.json.decode(content)["metadata"]
  end)

  if ok and metadata and metadata.kernelspec then
    kernel = metadata.kernelspec.name
    if vim.tbl_contains(available_kernels, kernel) then
      return kernel
    end
  end

  return nil
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
