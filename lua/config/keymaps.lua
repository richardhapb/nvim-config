local keymap = vim.keymap.set

-- Diagnostics and lint
keymap('n', '<leader>e', vim.diagnostic.open_float, { desc = "View diagnostic in a float windows" })
keymap('n', '<leader>]', vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })
keymap('n', '<leader>[', vim.diagnostic.goto_prev, { desc = "Go to previoues diagnostic" })

-- NVIM config
keymap('n', '<C-s', ':source %<CR>', { silent = true })

-- Edit
keymap('n', 'db', '"_dbx', { silent = true })
keymap('n', '<leader>cc', 'Vy', { silent = true })
keymap('n', '<leader>ca', 'ggVG')
keymap('n', 'x', '"_x', { silent = true })
keymap('n', 'D', '"_d$', { silent = true })
keymap('x', 'p', '"_xP')
keymap('v', 'J', ':m \'>+1<CR>gv=gv', {silent=true})
keymap('v', 'K', ':m \'<-2<CR>gv=gv', {silent=true})
keymap('n', '<leader>U', ':nohlsearch<CR>', {silent=true})
keymap('n', '*', '*N')
keymap('n', 'J', 'mzJ`z')
keymap('n', '<C-d>', '<C-d>zz')
keymap('n', '<C-u>', '<C-u>zz')
keymap('n', 'n', 'nzzzv')
keymap('n', 'N', 'Nzzzv')

-- UI
keymap('n', 'ss', ':split<CR><C-w>j', {silent = true})
keymap('n', 'sv', ':vsplit<CR><C-w>l', {silent = true})
keymap('n', '<C-q>', ':q<CR>', { silent = true })

-- Explorer
keymap('n', '-', require('oil').open, {desc = 'Open parent directory'})
keymap('n', '<leader>tn', ':tabnew<CR>', {silent=true, desc='New tab'})
keymap('n', '<leader>tf', ':tabnext<CR>', {silent=true, desc='New tab'})
keymap('n', '<leader>tb', ':tabprevious<CR>', {silent=true, desc='New tab'})
keymap('n', '<C-w><left>', '<C-w><')
keymap('n', '<C-w><right>', '<C-w>>')
keymap('n', '<C-w><up>', '<C-w>+')
keymap('n', '<C-w><down>', '<C-w>-')
