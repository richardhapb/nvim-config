local lsputils           = require 'functions.lsp'
local utils              = require 'functions.utils'

local M                  = {}

local SUPPORTED_LANGUGES = { "python", "lua", "rust", "bash", "go", "sh" }

local function normalize_ft(ft)
  if ft == "sh" then return "bash" end
  if ft == "zsh" then return "bash" end
  return ft
end

---Get the binary command depending of filetype
---@param ft string
---@return string[]?
local function get_binary_cmd(ft)
  local paths = {
    lua = { "lua" },
    python = { ft == "python" and lsputils.search_python_path(), "-u" }, -- The condition avoids looking for the path unnecessarily, -u flag forces the unbuffered output
    bash = { "bash", "-s" },
    rust = { "cargo", "run" },
    go = { "go", "run", "." }
  }

  return paths[ft]
end

---Check if a language use an interpreter, return True if it is
---@param ft string
---@return boolean?
local function use_interpreter(ft)
  local uses = {
    lua = true,
    python = true,
    bash = true,
    rust = false,
    go = false,
  }

  return uses[ft]
end

---Append lines to buffer
---@param buf integer
---@param lines string[]
local function append_to_buffer(buf, lines)
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
end

---Execute code lines
---@param code string[]
---@param args string?
local function execute_code(code, args)
  local ft = normalize_ft(vim.api.nvim_get_option_value("filetype", { buf = 0 }))
  local bin = get_binary_cmd(ft)
  if not bin then
    vim.notify("Language not supported: " .. ft, vim.log.levels.ERROR)
  end

  local job

  local float_buf = utils.buffer_log({}, { float = true, on_exit = function() if job then vim.fn.jobstop(job) end end })

  args = args or ""
  if args ~= "" then
    args = "- " .. args
    vim.list_extend(bin, vim.split(args, " ", { plain = true }))
  end

  job = vim.fn.jobstart(bin, {
    cwd = vim.fn.getcwd(),
    on_stdout = function(_, stdout)
      if stdout and #stdout > 0 then
        if stdout[#stdout] == "" then
          stdout = vim.split(vim.trim(table.concat(stdout, "\n")), "\n", { plain = true })
        end
        vim.schedule(function()
          append_to_buffer(float_buf, stdout)
        end)
      end
    end,
    on_stderr = function(_, stderr)
      if stderr and #stderr > 0 then
        vim.schedule(function()
          append_to_buffer(float_buf, stderr)
        end)
      end
    end,
    on_exit = function(_, _)
      vim.schedule(function()
        append_to_buffer(float_buf, { "[Process completed]" })
      end)
    end,
  })

  if use_interpreter(ft) then
    vim.fn.chansend(job, code)
    vim.fn.chanclose(job, "stdin")
  end
end

M.setup = function()
  vim.api.nvim_create_user_command("ExecuteCode", function(args)
      local line1 = 1
      local line2 = -1
      if args.range ~= 0 then
        line1 = args.line1
        line2 = args.line2
      end

      local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
      execute_code(lines, args.args)
    end,
    {
      nargs = '?',
      complete = 'file',
      range = 1
    })

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("CodeExecutor", { clear = true }),
    pattern = SUPPORTED_LANGUGES,
    callback = function(args)
      vim.keymap.set({ 'x' }, '<leader>=', '<ESC><CMD>\'<,\'>ExecuteCode<CR>',
        { noremap = true, buffer = args.buf, silent = true, desc = 'Execute selected code' })
      vim.keymap.set({ 'n' }, '<leader>=', '<CMD>ExecuteCode<CR>',
        { noremap = true, buffer = args.buf, silent = true, desc = 'Execute whole code' })
    end
  })
end

return M
