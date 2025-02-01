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
