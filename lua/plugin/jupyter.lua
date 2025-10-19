local CELL_MARKER_COLOR = "#A5A5A5"
local CELL_FG_COLOR = "#000000"
local CELL_MARKER = "^# %%%%"
local CELL_MARKER_SIGN = "cell_marker_sign"

local jupyter_group = vim.api.nvim_create_augroup("JupyterConfig", { clear = true })


local function setup()
  vim.api.nvim_set_hl(0, "cell_marker_hl", { bg = CELL_MARKER_COLOR, fg = CELL_FG_COLOR })
  vim.fn.sign_define(CELL_MARKER_SIGN, { linehl = "cell_marker_hl" })

  local function highlight_cell_marker(bufnr, line)
    local sign_name = CELL_MARKER_SIGN
    local sign_text = "%%"
    vim.fn.sign_place(line, CELL_MARKER_SIGN, sign_name, bufnr, {
      lnum = line,
      priority = 10,
      text = sign_text,
    })
  end

  local function show_cell_markers()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.fn.sign_unplace(CELL_MARKER_SIGN, { buffer = bufnr })
    local total_lines = vim.api.nvim_buf_line_count(bufnr)
    for line = 1, total_lines do
      local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
      if line_content ~= "" and line_content:find(CELL_MARKER) then
        highlight_cell_marker(bufnr, line)
      end
    end
  end

  local function show_cell_marker()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
    if line_content ~= "" and line_content:find(CELL_MARKER) then
      highlight_cell_marker(bufnr, line)
    else
      vim.fn.sign_unplace(CELL_MARKER_SIGN, { buffer = bufnr, id = line })
    end
  end

  local function select_cell()
    local bufnr = vim.api.nvim_get_current_buf()
    local current_row, current_col = unpack(vim.api.nvim_win_get_cursor(0))

    local start_line = nil
    local end_line = nil

    for line = current_row, 1, -1 do
      local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
      if line_content:find(CELL_MARKER) then
        start_line = line
        break
      end
    end
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    for line = current_row + 1, line_count do
      local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
      if line_content:find(CELL_MARKER) then
        end_line = line
        break
      end
    end

    if not start_line then
      start_line = 1
    end
    if not end_line then
      end_line = line_count
    end

    local end_col = #vim.api.nvim_buf_get_lines(0, end_line - 1, end_line, false)[1]
    return current_row, current_col, start_line, end_line, end_col
  end

  local function execute_cell()
    local current_row, current_col, start_line, end_line, end_col = select_cell()
    if start_line and end_line then
      vim.fn.setpos("'<", { 0, start_line + 1, 0, 0 })
      vim.fn.setpos("'>", { 0, end_line - 1, end_col, 0 })
      vim.cmd "MoltenEvaluateVisual"
      vim.api.nvim_win_set_cursor(0, { current_row, current_col })
    end
  end

  local function execute_all_cells()
    local current_row, current_col = unpack(vim.api.nvim_win_get_cursor(0))
    local line_count = vim.api.nvim_buf_line_count(0)
    vim.fn.setpos("'<", { 0, 1, 0, 0 })
    vim.fn.setpos("'>", { 0, line_count, 0, 0 })
    vim.cmd "MoltenEvaluateVisual"
    vim.api.nvim_win_set_cursor(0, { current_row, current_col })
  end

  local function delete_cell()
    local _, _, start_line, end_line = select_cell()
    if start_line and end_line then
      local rows_to_select = end_line - start_line - 1
      vim.api.nvim_win_set_cursor(0, { start_line, 0 })
      vim.cmd("normal!V " .. rows_to_select .. "j")
      vim.cmd "normal!d"
      vim.cmd "normal!k"
    end
  end

  local function navigate_cell(up)
    local is_up = up or false
    local _, _, start_line, end_line = select_cell()
    if is_up and start_line ~= 1 then
      vim.api.nvim_win_set_cursor(0, { start_line - 1, 0 })
    elseif end_line then
      local bufnr = vim.api.nvim_get_current_buf()
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      if end_line ~= line_count then
        vim.api.nvim_win_set_cursor(0, { end_line + 1, 0 })
        _, _, start_line, end_line = select_cell()
        vim.api.nvim_win_set_cursor(0, { end_line - 1, 0 })
      end
    end
  end

  local function insert_cell(content)
    local _, _, _, end_line = select_cell()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = end_line
    if end_line ~= 1 then
      line = end_line - 1
      vim.api.nvim_win_set_cursor(0, { end_line - 1, 0 })
    else
      line = end_line
      vim.api.nvim_win_set_cursor(0, { end_line, 0 })
    end

    vim.cmd "normal!2o"
    vim.api.nvim_buf_set_lines(bufnr, line, line + 1, false, { content })
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    highlight_cell_marker(bufnr, current_line - 1)
    vim.cmd "normal!2o"
    vim.cmd "normal!k"
  end

  local function insert_code_cell()
    insert_cell "# %%"
  end

  local function insert_markdown_cell()
    insert_cell "# %% [markdown]"
  end

  -- The destination format: 'ipynb', 'markdown' or 'script', or a file extension: 'md', 'Rmd', 'jl', 'py', 'R', ..., 'auto' (script
  -- extension matching the notebook language), or a combination of an extension and a format name, e.g. md:markdown, md:pandoc,
  -- md:myst or py:percent, py:light, py:nomarker, py:hydrogen, py:sphinx. The default format for scripts is the 'light' format,
  -- which uses few cell markers (none when possible). Alternatively, a format compatible with many editors is the 'percent' format,
  -- which uses '# %%' as cell markers. The main formats (markdown, light, percent) preserve notebooks and text documents in a
  -- roundtrip. Use the --test and and --test-strict commands to test the roundtrip on your files. Read more about the available
  -- formats at https://jupytext.readthedocs.io/en/latest/formats.html (default: None)
  vim.g.jupytext_fmt = "py:percent"

  -- Autocmd to set cell markers
  vim.api.nvim_create_autocmd({ "BufEnter" }, { -- "BufWriteCmd"
    group = jupyter_group,
    pattern = { "*.ipynb", "*.r", "*.jl", "*.scala" },
    callback = function()
      vim.schedule(show_cell_markers)
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    group = jupyter_group,
    pattern = { "*.ipynb", "*.r", "*.jl", "*.scala" },
    callback = function()
      vim.schedule(show_cell_marker)
    end,
  })

  -- Avoid jsonls attached in a new jupyter notebook
  vim.api.nvim_create_autocmd("FileType", {
    group = jupyter_group,
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


  local keys = {
    { "<localleader>x", function() vim.cmd "MoltenReevaluateCell" end, desc = "Execute Cell" },
    { "<localleader>X", function() vim.cmd "MoltenReevaluateAll" end,  desc = "Execute All Cells" },
    { "<localleader>i", insert_code_cell,                              desc = "Insert Code Cell" },
    { "<localleader>m", insert_markdown_cell,                          desc = "Insert Markdown Cell" },
    { "<localleader>d", delete_cell,                                   desc = "Delete Cell" },
    { "<localleader>n", navigate_cell,                                 desc = "Next Cell" },
    { "<localleader>M", show_cell_markers,                             desc = "Reload markers" },
    { "<localleader>p", function() navigate_cell(true) end,            desc = "Previous Cell" },
    {
      "<localleader>v",
      function()
        vim.cmd.normal(""); vim.cmd "MoltenEvaluateVisual"
      end,
      mode = { "v" },
      desc = "Send"
    },
    { "<localleader>l", function() vim.cmd "MoltenEvaluateLine" end, desc = "Send Line" },
    -- { "<leader>xt",     function() require("iron.core").send_until_cursor() end,        desc = "Send Until Cursor" },
  }

  for _, key in ipairs(keys) do
    local mode = key["mode"] or "n"
    local desc = key["desc"] or ""
    vim.keymap.set(mode, key[1], key[2], { desc = desc })
  end

  -- automatically import output chunks from a jupyter notebook
  -- tries to find a kernel that matches the kernel in the jupyter notebook
  -- falls back to a kernel that matches the name of the active venv (if any)
  local imb = function(e) -- init molten buffer
    vim.schedule(function()
      local kernels = vim.fn.MoltenAvailableKernels()
      local try_kernel_name = function()
        local metadata = vim.json.decode(io.open(e.file, "r"):read("a"))["metadata"]
        return metadata.kernelspec.name
      end
      local ok, kernel_name = pcall(try_kernel_name)
      if not ok or not vim.tbl_contains(kernels, kernel_name) then
        kernel_name = nil
        local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
        if venv ~= nil then
          kernel_name = string.match(venv, "/.+/(.+)")
        end
      end
      if kernel_name ~= nil and vim.tbl_contains(kernels, kernel_name) then
        vim.cmd(("MoltenInit %s"):format(kernel_name))
      end
      vim.cmd("MoltenImportOutput")
    end)
  end

  -- automatically import output chunks from a jupyter notebook
  vim.api.nvim_create_autocmd("BufAdd", {
    group = jupyter_group,
    pattern = { "*.ipynb" },
    callback = imb,
  })

  -- we have to do this as well so that we catch files opened like nvim ./hi.ipynb
  vim.api.nvim_create_autocmd("BufEnter", {
    group = jupyter_group,
    pattern = { "*.ipynb" },
    callback = function(e)
      if vim.api.nvim_get_vvar("vim_did_enter") ~= 1 then
        imb(e)
      end
    end,
  })

  -- automatically export output chunks to a jupyter notebook on write
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = jupyter_group,
    pattern = { "*.ipynb" },
    callback = function()
      if require("molten.status").initialized() == "Molten" then
        vim.cmd("MoltenExportOutput!")
      end
    end,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    pattern = { "*.ipynb" },
    callback = function(e)
      local client = vim.lsp.get_client_by_id(e.data.client_id)
      if client and client.name == "pyright" and client.settings then
        local new = {
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
        client.settings.python = vim.tbl_deep_extend('force', client.settings.python, new)
        -- Even more lenient settings specifically for notebooks
        vim.defer_fn(function()
          client:notify("workspace/didChangeConfiguration", {
            settings = nil
          })
        end, 100)
      end
    end,
  })
end


return {
  setup = setup
}
