local utils = require 'functions.utils'

local keymap = vim.keymap.set

-- Diagnostics and lint
keymap('n', '<leader>e', vim.diagnostic.open_float, { desc = "View diagnostic in a float windows" })
keymap('n', '<leader>]', function() vim.diagnostic.jump({ count = 1, float = true }) end,
   { desc = "Go to next diagnostic" })
keymap('n', '<leader>[', function() vim.diagnostic.jump({ count = -1, float = true }) end,
   { desc = "Go to previous diagnostic" })

-- Usercommands
keymap('n', '<leader>do', ':DiffOrig<CR>', { silent = true, desc = 'Compare with original' })

-- NVIM config
keymap('n', '<C-s>', ':source %<CR>', { silent = true })

-- Edit
keymap('n', 'db', '"_dbx', { silent = true })
keymap('n', '<leader>cc', 'Vy', { silent = true })
keymap('n', '<leader>ca', 'ggVG')
keymap('n', 'x', '"_x', { silent = true })
keymap('n', 'D', '"_d$', { silent = true })
keymap('x', 'p', '"_xP')
keymap('v', 'J', ':m \'>+1<CR>gv=gv', { silent = true })
keymap('v', 'K', ':m \'<-2<CR>gv=gv', { silent = true })
keymap('n', '<leader>U', ':nohlsearch<CR>', { silent = true })
keymap('n', '*', '*N')
keymap('n', 'J', 'mzJ`z')
keymap('n', '<C-d>', '<C-d>zz')
keymap('n', '<C-u>', '<C-u>zz')
keymap('n', 'n', 'nzzzv')
keymap('n', 'N', 'Nzzzv')

-- Quickfix
keymap('n', '<C-n>', ':cnext<CR>', { silent = true })
keymap('n', '<C-p>', ':cprev<CR>', { silent = true })

-- UI
keymap('n', 'ss', ':split<CR><C-w>j', { silent = true })
keymap('n', 'sv', ':vsplit<CR><C-w>l', { silent = true })
keymap('n', '<C-q>', ':q<CR>', { silent = true })


-- Explorer
keymap('n', '-', require('oil').open, { desc = 'Open parent directory' })
keymap('n', '<leader>tc', ':tabnew<CR>', { silent = true, desc = 'New tab' })
keymap('n', '<leader>tn', ':tabnext<CR>', { silent = true, desc = 'Next tab' })
keymap('n', '<leader>tp', ':tabprevious<CR>', { silent = true, desc = 'Previous tab' })
keymap('n', '<C-w><left>', '15<C-w><')
keymap('n', '<C-w><right>', '15<C-w>>')
keymap('n', '<C-w><up>', '5<C-w>+')
keymap('n', '<C-w><down>', '5<C-w>-')
keymap('n', '<leader>bi', utils.close_all_buffers_but_current,
   { silent = true, desc = 'Close all buffers except current' })
keymap('n', '<leader>bd', ':bd<CR>', { silent = true, desc = 'Close buffer' })
keymap('n', '<C-\\>', '<C-6>', { silent = true, desc = 'Switch to last buffer' })

-- Git
keymap('n', '<leader>gg', ':G<CR>', { silent = true, desc = 'Git status' })
keymap('n', '<leader>gc', ':G commit<CR>', { silent = true, desc = 'Git commit' })
keymap('n', '<leader>gC', ':G commit --amend<CR>', { silent = true, desc = 'Git commit --amend' })
keymap('n', '<leader>gP', ':G push<CR>', { silent = true, desc = 'Git push' })
keymap('n', '<leader>gp', ':G pull<CR>', { silent = true, desc = 'Git pull' })
keymap('n', '<leader>gS', ':G stash<CR>', { silent = true, desc = 'Git stash' })
keymap('n', '<leader>gA', ':G add .<CR>', { silent = true, desc = 'Git add .' })
keymap('n', '<leader>gdd', ':G diff<CR>', { silent = true, desc = 'Git diff' })
keymap('n', '<leader>gf', ':G fetch<CR>', { silent = true, desc = 'Git fetch' })
keymap('n', '<leader>gb', ':G blame<CR>', { silent = true, desc = 'Git blame' })
keymap('n', '<leader>ghh', ':Gitsigns preview_hunk<CR>', { silent = true, desc = 'Git preview hunk' })
keymap('n', '<leader>gdv', ':Gvdiffsplit<CR>', { silent = true, desc = 'Git vertical diff split' })
keymap('n', '<leader>gds', ':Gdiffsplit<CR>', { silent = true, desc = 'Git horizontal diff split' })
keymap({ 'n', 'x' }, '<leader>ghh', ':Gitsigns preview_hunk<CR>', { silent = true, desc = 'Git preview hunk' })
keymap({ 'n', 'x' }, '<leader>ghp', ':Gitsigns prev_hunk<CR>', { silent = true, desc = 'Git previous hunk' })
keymap({ 'n', 'x' }, '<leader>ghn', ':Gitsigns next_hunk<CR>', { silent = true, desc = 'Git next hunk' })
keymap({ 'n', 'x' }, '<leader>ghr', ':Gitsigns reset_hunk<CR>', { silent = true, desc = 'Git reset hunk' })



keymap('n', '<leader>gda', function()
   utils.git_diff_name_only('HEAD')
   utils.close_all_buffers_but_current()
end, { silent = true, desc = 'Git diff HEAD --name-only' })

-- Copilot
keymap('i', '<C-z>', 'copilot#Accept()',
   { expr = true, silent = true, desc = 'Copilot complete', noremap = false, replace_keycodes = false })

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

