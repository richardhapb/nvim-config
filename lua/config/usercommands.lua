local lsputils = require 'functions.lsp'

vim.api.nvim_create_user_command(
  'DiffOrig',
  function()
    local current_buffer = vim.api.nvim_get_current_buf()
    local another_buffer = vim.api.nvim_create_buf(false, true)

    local filename = vim.api.nvim_buf_get_name(current_buffer)
    if filename == '' then
      print('No file name')
      return
    end

    local ok, result = pcall(vim.fn.readfile, filename)
    if not ok then
      vim.notify('Error reading file: ' .. result, vim.log.levels.ERROR)
      return
    end
    vim.api.nvim_buf_set_lines(another_buffer, 0, -1, false, result)

    require 'functions.utils'.diff_buffers(current_buffer, another_buffer)
  end,
  { desc = 'Compare current buffer with the original file' }
)

vim.api.nvim_create_user_command(
  'GPU',
  function()
    vim.cmd('G push -u')
  end,
  { desc = 'Git push to upstream' }
)

vim.api.nvim_create_user_command(
  'CWD',
  function()
    vim.cmd('lcd %:p:h')
    print('Current working directory: ' .. vim.fn.getcwd())
  end,
  { desc = 'Set current working directory' }
)

-- Take Richard or Syzlab arguments
vim.api.nvim_create_user_command(
  'GitHubLogin',
  function(opts)
    local user = opts.args
    if user == '' then
      print('No user provided')
      return
    end

    local token = ""

    if user == 'richard' then
      token = vim.env.GH_RICHARD_TOKEN
    else
      token = vim.env.GH_SYZLAB_TOKEN
    end

    if not token or token == '' then
      print('No token found')
      return
    end

    vim.fn.jobstart('echo ' .. token .. ' | gh auth login --with-token', {
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          vim.notify('Logged in to GitHub with ' .. user, vim.log.levels.INFO)
        else
          vim.notify('Error logging in to GitHub', vim.log.levels.ERROR)
        end
      end
    })
  end,
  {
    nargs = 1,
    desc = 'Login to GitHub',
    complete = function(_, _, _)
      return { 'richard', 'syzlab' }
    end
  }
)

---@param names string[]
local function stop_clients(names)
  vim.lsp.enable(names, false)
end

---@param names string[]
local function start_clients(names)
  for _, name in ipairs(names) do
    local config = vim.lsp._enabled_configs[name].resolved_config
    vim.lsp.start(config, { attach = true, silent = false })
  end
end

local function lsp_cmd(opts, cmd_f)
  local names_arg = opts.args
  if names_arg == "" then
    vim.notify("Client name is required", vim.log.levels.ERROR)
    return
  end

  local names = vim.split(names_arg, " ", { plain = true, silent = false, reuse_client = false })
  cmd_f(names)
end

local lsp_cmd_opts = {
  nargs = 1,
  desc = "LSP client",
  complete = lsputils.get_active_clients_names
}

vim.api.nvim_create_user_command("LspStart",
  function(opts)
    lsp_cmd(opts, start_clients)
  end,
  lsp_cmd_opts
)

vim.api.nvim_create_user_command(
  "LspRestart",
  function(opts)
    lsp_cmd(opts, function(names)
      stop_clients(names)
      vim.defer_fn(function() start_clients(names) end, 5000)
    end)
  end,
  lsp_cmd_opts
)

vim.api.nvim_create_user_command(
  "LspStop",
  function(opts)
    lsp_cmd(opts, stop_clients)
  end,
  lsp_cmd_opts
)

vim.api.nvim_create_user_command(
  "LspLog",
  function()
    local log = vim.lsp.log.get_filename()
    vim.cmd("tabnew " .. log)
  end,
  {
    nargs = 0,
  }
)
