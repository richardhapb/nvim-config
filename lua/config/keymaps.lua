local utils = require 'functions.utils'

local keymap = vim.keymap.set
local k = vim.keycode

local function _verify_tmux()
  local tmux_running = false
  if vim.fn.executable 'tmux' == 1 then
    vim.cmd('silent !tmux info')
    tmux_running = vim.v.shell_error == 0
  end

  return tmux_running
end

-- Usercommands
keymap('n', '<leader>do', ':DiffOrig<CR>', { silent = true, desc = 'Compare with original' })

-- Lua dev
keymap('n', '<C-s>', '<cmd>source %<CR>', { noremap = true, desc = 'Source file' })
keymap('n', '<C-x>', '<cmd>.lua<CR>', { desc = 'Execute lua line' })

-- Edit
keymap('n', '-', '<cmd>edit %:p:h<cr>', { silent = true })
keymap('n', 'db', '"_db', { silent = true })
keymap('n', 'de', '"_de', { silent = true })
keymap('n', 'dw', '"_dw', { silent = true })
keymap('n', '<leader>sa', 'ggVG', { silent = true, desc = 'Select all' })
keymap('n', 'D', '"_d$', { silent = true })
keymap('x', 'p', '"_xP', { silent = true })
keymap('v', 'J', ':m \'>+1<CR>gv=gv', { silent = true })
keymap('v', 'K', ':m \'<-2<CR>gv=gv', { silent = true })
keymap('n', '*', '*N', { noremap = true, silent = true })
keymap('n', 'J', 'mzJ`z')
keymap('n', '<C-d>', '<C-d>zz')
keymap('n', '<C-u>', '<C-u>zz')
keymap('n', 'n', 'nzzzv')
keymap('n', 'N', 'Nzzzv')
keymap('n', '+', '<C-a>', { noremap = true, silent = true, desc = 'Increment number' })
-- Remove search highlight if is active
keymap('n', '<Esc>', function()
  if vim.v.hlsearch == 1 then
    vim.cmd.nohl()
    return ''
  else
    return k '<Esc>'
  end
end, { expr = true })


-- UI
keymap('n', 'ss', ':split<CR><C-w>j', { silent = true })
keymap('n', 'sv', ':vsplit<CR><C-w>l', { silent = true })
keymap('n', '<C-q>', ':q<CR>', { silent = true })
keymap('n', '<C-bp>', '<CMD>bprevious<CR>', { silent = true, noremap = true })
keymap('n', '<C-bn>', '<CMD>bnext<CR>', { silent = true, noremap = true })

-- Explorer
keymap('n', '<leader>\\', ':tabnew<CR>', { silent = true, desc = 'New tab' })
keymap('n', '<C-n>', ':tabnext<CR>', { silent = true, desc = 'Next tab' })
keymap('n', '<C-p>', ':tabprevious<CR>', { silent = true, desc = 'Previous tab' })
keymap('n', '<leader>qq', ':tabclose<CR>', { silent = true, desc = 'Close tab' })
keymap('n', '<C-w><left>', '15<C-w><')
keymap('n', '<C-w><right>', '15<C-w>>')
keymap('n', '<C-w><up>', '5<C-w>+')
keymap('n', '<C-w><down>', '5<C-w>-')
keymap('n', '<leader>bd', ':bd!<CR>', { silent = true, desc = 'Close buffer' })
keymap('n', '<leader>.', '<cmd>e tags<cr>', { silent = true, desc = 'Open tags' })

if not _verify_tmux() then
  keymap('n', '<C-h>', '<C-w>h', { silent = true })
  keymap('n', '<C-j>', '<C-w>j', { silent = true })
  keymap('n', '<C-k>', '<C-w>k', { silent = true })
  keymap('n', '<C-l>', '<C-w>l', { silent = true })
end


-- Open the current selection, can be a file or a link, if it is a oil buffer, open the file selected.
keymap({ 'x', 'n' }, '<leader>o', function()
  local cmd = vim.fn.has "win32" == 1 and "explorer.exe" or vim.fn.has "mac" == 1 and "open" or "xdg-open"
  local input = utils.get_visual_selection()
  input = input:gsub('\n', '')

  -- If there is not selection, get the word under the cursor
  if input == '' then
    vim.cmd('normal! "xyiW')
    input = vim.fn.getreg 'x'
  end

  local file_dir
  -- If the filetype is oil, get the current directory and line
  if vim.api.nvim_get_option_value('filetype', { buf = 0 }) == 'oil' then
    local ok, oil = pcall(require, 'oil')
    if ok then
      file_dir = oil.get_current_dir()
      -- Oil lines have the form "line icon file"
      input = vim.fn.getline('.'):gsub('^.*%s.*%s', '')
    end
  else
    file_dir = vim.fn.expand('%:p:h')
  end

  if not file_dir or not input or input == '' then
    return
  end

  local path = vim.fs.joinpath(file_dir, input)
  local args

  if vim.fn.filereadable(path) == 1 then
    args = path
  elseif input:find 'http' or input:find 'www' then
    args = input
  end

  if not args then
    return
  end

  vim.fn.jobstart({ cmd, args }, { detach = true })
end, { desc = 'Open current selection' })

--- @param note string
local create_note = function(note)
  if note == '' then
    return
  end
  local path = vim.fs.joinpath(vim.fn.expand('$NOTES'), 'inbox', note .. '.md')

  vim.cmd('edit ' .. path)
  vim.notify('Note ' .. path .. ' loaded successfully', vim.log.levels.INFO)
end

keymap('n', '<leader>nn', function()
  local note = vim.fn.input('Note: ')
  create_note(note)
end, { silent = true, desc = 'Create a new note' })

keymap('n', '<leader>nb', function()
  local repository = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
  local branch = vim.fn.system('git branch --show-current')
  branch = vim.fn.trim(branch)

  if branch == '' then
    vim.notify('Not in a git repository', vim.log.levels.ERROR)
    return
  end

  -- If branch has a slash, get the last part
  if string.find(branch, '/') then
    local branch_sections = vim.fn.split(branch, '/')
    branch = branch_sections[#branch_sections]
  end

  create_note(repository .. '-' .. branch)
end, { silent = true, desc = 'Create a new note for branch' })

-- Git
keymap('n', '<leader>gg', ':G<CR>', { silent = true, desc = 'Git status' })
keymap('n', '<leader>gc', ':G commit<CR>', { silent = true, desc = 'Git commit' })
keymap('n', '<leader>gC', ':G commit --amend<CR>', { silent = true, desc = 'Git commit --amend' })
keymap('n', '<leader>gP', ':G push<CR>', { silent = true, desc = 'Git push' })
keymap('n', '<leader>gp', ':G pull<CR>', { silent = true, desc = 'Git pull' })
keymap('n', '<leader>gS', ':G stash<CR>', { silent = true, desc = 'Git stash' })
keymap('n', '<leader>gA', ':G add .<CR>', { silent = true, desc = 'Git add .' })
keymap('n', '<leader>gdd', ':G diff<CR>', { silent = true, desc = 'Git diff' })
keymap('n', '<leader>gf', ':G fetch --all<CR>', { silent = true, desc = 'Git fetch' })
keymap('n', '<leader>gb', ':G blame<CR>', { silent = true, desc = 'Git blame' })
keymap('n', '<leader>ghh', ':Gitsigns preview_hunk<CR>', { silent = true, desc = 'Git preview hunk' })
keymap('n', '<leader>gdv', ':Gvdiffsplit<CR>', { silent = true, desc = 'Git vertical diff split' })
keymap('n', '<leader>gds', ':Gdiffsplit<CR>', { silent = true, desc = 'Git horizontal diff split' })
keymap({ 'n', 'x' }, '<leader>ghh', ':Gitsigns preview_hunk<CR>', { silent = true, desc = 'Git preview hunk' })
keymap({ 'n', 'x' }, '[g', ':Gitsigns prev_hunk<CR>', { silent = true, desc = 'Git previous hunk' })
keymap({ 'n', 'x' }, ']g', ':Gitsigns next_hunk<CR>', { silent = true, desc = 'Git next hunk' })
keymap({ 'n', 'x' }, '<leader>ghr', ':Gitsigns reset_hunk<CR>', { silent = true, desc = 'Git reset hunk' })

-- New worktree with branch name
keymap('n', '<leader>gw', function()
  local name = vim.fn.input('Worktree name: ')
  require 'git-worktree'.create_worktree(name, name)
end, { silent = true, desc = 'Git worktree' })


-- Work's standard branch naming convention
-- feature/richard/yy-mm-dd-feature-name
-- combined with worktree workflow
keymap('n', '<leader>g+', function()
  local feature = vim.fn.input('Feature: ')
  local worktree_name = vim.fn.input('Worktree name: ')

  local branch_name = 'feature/richard/' .. os.date('%y-%m-%d') .. '-' .. feature
  branch_name = string.gsub(branch_name, '%s+', '-')
  vim.notify('Creating branch ' .. branch_name, vim.log.levels.INFO)
  vim.fn.system('git fetch origin')
  vim.fn.system('git update-ref refs/heads/development origin/development')
  vim.fn.system('git branch ' .. branch_name .. ' development')

  require 'git-worktree'.create_worktree(worktree_name, branch_name)

  vim.notify('Branch ' .. branch_name .. ' created successfully', vim.log.levels.INFO)

  local upstream = vim.fn.input('You want to set upstream? [y/n]: ')
  if upstream == 'y' then
    vim.fn.system('git push -u origin ' .. branch_name)
    vim.notify('Branch ' .. branch_name .. ' set upstream successfully', vim.log.levels.INFO)
  end
end, { silent = true, desc = 'Git add a branch and switch' })

-- Set upstream
keymap('n', '<leader>gu', function()
  local branch_name = vim.fn.system('git branch --show-current')
  local upstream = vim.fn.input('You want to set upstream to ' .. branch_name .. '? [y/n]: ')
  if upstream == 'y' then
    vim.fn.system('git push -u origin ' .. branch_name)
    vim.notify('Branch ' .. branch_name .. ' set upstream successfully', vim.log.levels.INFO)
  end
end, { silent = true, desc = 'Git set upstream' })

-- Git diff for file name only
keymap('n', '<leader>gda', function()
  utils.git_diff_name_only('HEAD')
  utils.close_all_buffers_but_current()
end, { silent = true, desc = 'Git diff HEAD --name-only' })

keymap('n', 'gh', '<CMD>diffget //2<CR>', { silent = true, desc = 'Git diff get left' })
keymap('n', 'gl', '<CMD>diffget //3<CR>', { silent = true, desc = 'Git diff get right' })

-- Latex
keymap('n', '<leader>lb', ':LatexBuild<CR>', { silent = true, desc = 'Latex build' })
keymap('n', '<leader>lp', ':TeXpresso %<CR>', { silent = true, desc = 'Latex preview' })

-- Spanish
keymap('i', '<A-e>a', 'á', { silent = true })
keymap('i', '<A-e>e', 'é', { silent = true })
keymap('i', '<A-e>i', 'í', { silent = true })
keymap('i', '<A-e>o', 'ó', { silent = true })
keymap('i', '<A-e>u', 'ú', { silent = true })
keymap('i', '<A-n>n', 'ñ', { silent = true })
keymap('i', '<A-e>A', 'Á', { silent = true })
keymap('i', '<A-e>E', 'É', { silent = true })
keymap('i', '<A-e>I', 'Í', { silent = true })
keymap('i', '<A-e>O', 'Ó', { silent = true })
keymap('i', '<A-e>U', 'Ú', { silent = true })
keymap('i', '<A-n>N', 'Ñ', { silent = true })
keymap('i', '<A-?>', '¿', { silent = true })
keymap('i', '<A-1>', '¡', { silent = true })

-- Python
keymap('n', '<leader>rp', ':!python %<CR>', { silent = true, desc = 'Run python' })

-- Rust
keymap('n', '<leader>rr', ':!cargo run<CR>', { silent = true, desc = 'Run cargo' })
keymap('n', '<leader>rc', ':!cargo check<CR>', { silent = true, desc = 'Check cargo' })
keymap('n', '<leader>rt', ':!cargo test<CR>', { silent = true, desc = 'Test cargo' })

-- Misc
keymap('n', '<leader>u', ':UndotreeToggle<CR>', { silent = true, desc = 'Undo tree' })

-- Terminal
keymap('t', '<esc><esc>', "<C-\\><C-n>", { silent = true, desc = 'Normal mode in terminal' })

keymap('n', '<leader>cc', "<CMD>term<CR><CMD>startinsert<CR>", { silent = true, desc = 'Open terminal' })
keymap('n', '<leader>cb', function()
  vim.cmd.vnew()
  vim.cmd.term()
  vim.cmd.wincmd 'J'
  vim.api.nvim_win_set_height(0, 10)
  vim.cmd.startinsert()
end, { silent = true, desc = 'Open terminal on bottom' })
