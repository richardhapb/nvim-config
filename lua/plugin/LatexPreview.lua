local utils = require 'functions.utils'

local M = {}

M.setup = function()
  vim.api.nvim_create_user_command('LatexBuild', function()
    vim.notify('Building ' .. vim.fn.expand('%:t') .. '...')
    local build_dir = vim.fn.expand('%:p:h') .. '/build'
    local file_path = vim.fn.expand('%:p')
    local basename = vim.fn.fnamemodify(file_path, ':t:r')
    local source_dir = vim.fn.expand('%:p:h')

    -- Verify if the build directory exists, if not, create it
    if vim.fn.isdirectory(build_dir) == 0 then
      vim.fn.mkdir(build_dir, 'p')
    end

    -- Verify if some .bib file exists in the same directory
    local biblio = vim.fn.glob(source_dir .. '/*.bib')

    local function run_command(cmd)
      return vim.fn.system('cd ' .. vim.fn.shellescape(source_dir) .. ' && ' .. cmd)
    end

    local build_command = string.format(
      'xelatex -output-directory=%s -interaction=nonstopmode -halt-on-error -shell-escape %s',
      vim.fn.shellescape(build_dir),
      vim.fn.shellescape(file_path)
    )

    -- Initial latex compilation
    local results = run_command(build_command)

    -- If a .bib file exists, run bibtex and rebuild
    if vim.fn.filereadable(biblio) == 1 then
      -- Set BIBINPUTS environment variable to include both directories
      local bibtex_cmd = string.format(
        'cd %s && BIBINPUTS=%s:%s: bibtex %s',
        vim.fn.shellescape(build_dir),
        vim.fn.shellescape(source_dir),
        vim.fn.shellescape(build_dir),
        vim.fn.shellescape(basename)
      )
      results = results .. "\n" .. vim.fn.system(bibtex_cmd)

      -- Run latex again twice after bibliography processing
      for _ = 1, 2 do
        results = results .. "\n" .. run_command(build_command)
      end
    else
      -- If no bibliography, run latex one more time for cross-references
      results = results .. "\n" .. run_command(build_command)
    end

    local buffer = utils.buffer_log(vim.split(results, '\n', { plain = true }), {})

    -- Open the pdf file after the build
    vim.api.nvim_create_autocmd('BufUnload', {
      buffer = buffer,
      callback = function()
        vim.system({ 'open', build_dir .. '/' .. basename .. '.pdf' })
      end
    })

    vim.notify('Build complete')
  end, {})

  vim.api.nvim_create_user_command('LatexPreview', function()
    -- Verify if Texpresso command is available in vim (plugin)
    if vim.fn.exists(':TeXpresso') ~= 0 then
      vim.cmd('TeXpresso %')
      return
    end
    vim.notify('TeXpresso command not found. Install the plugin for live preview')

    if vim.fn.executable('texpresso') == 0 then
      vim.notify('texpresso is not installed, install it')
      return
    end

    if vim.fn.executable('tmux') == 0 then
      vim.notify('tmux is not installed, install it')
      return
    end

    vim.notify('Previewing ' .. vim.fn.expand('%:t') .. 'with texpresso (no live preview)')

    local tex_path = vim.fn.expand('%:p')
    local command = string.format(
      'tmux new-session -d -s texpresso "texpresso %s"',
      tex_path
    )
    vim.fn.system(command)
  end, {})

  vim.api.nvim_create_user_command('LatexShutdown', function()
    if vim.fn.exists(':TeXpresso') ~= 0 then
      vim.notify('Close TeXpresso with "q" in the preview window')
      return
    end

    if vim.fn.executable('tmux') == 0 then
      vim.notify('tmux not available')
      return
    end

    local _ = vim.fn.system('tmux has-session -t texpresso 2>/dev/null')
    if vim.v.shell_error ~= 0 then
      vim.notify('Nothing to shutdown')
      return
    end
    vim.fn.system('tmux kill-session -t texpresso')
    vim.notify('TeXpresso session terminated')
  end, {})
end
return M
