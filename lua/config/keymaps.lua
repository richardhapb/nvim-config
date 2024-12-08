local keymap = vim.keymap.set

-- Diagnostics and lint
keymap('n', '<leader>e', vim.diagnostic.open_float, { desc = "View diagnostic in a float windows" })
keymap('n', '<leader>]', vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })
keymap('n', '<leader>[', vim.diagnostic.goto_prev, { desc = "Go to previoues diagnostic" })

-- Edit
keymap('n', 'db', '"_dbx', { silent = true })
keymap('n', '<leader>cc', 'Vy', { silent = true })
keymap('n', 'x', '"_x', { silent = true })
keymap('n', 'df', '"_d$', { silent = true })

-- UI
keymap('n', 'ss', ':split<CR>', {silent = true})
keymap('n', 'sv', ':vsplit<CR>', {silent = true})
keymap('n', '<C-q>', ':q<CR>', { silent = true })

-- Explorer
keymap('n', '-', require('oil').open, {desc = 'Open parent directory'})

