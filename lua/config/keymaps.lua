local keymap = vim.keymap.set

-- Diagnostics and lint
keymap('n', '<leader>e', vim.diagnostic.open_float, { desc = "View diagnostic in a float windows" })
keymap('n', '<leader>]', vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })
keymap('n', '<leader>[', vim.diagnostic.goto_prev, { desc = "Go to previoues diagnostic" })

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

-- UI
keymap('n', 'ss', ':split<CR><C-w>j', { silent = true })
keymap('n', 'sv', ':vsplit<CR><C-w>l', { silent = true })
keymap('n', '<C-q>', ':q<CR>', { silent = true })

local close_all_buffers_but_current = function()
   vim.cmd(':%bd|e#')
end

-- Explorer
keymap('n', '-', require('oil').open, { desc = 'Open parent directory' })
keymap('n', '<leader>tn', ':tabnew<CR>', { silent = true, desc = 'New tab' })
keymap('n', '<leader>tf', ':tabnext<CR>', { silent = true, desc = 'New tab' })
keymap('n', '<leader>tb', ':tabprevious<CR>', { silent = true, desc = 'New tab' })
keymap('n', '<C-w><left>', '15<C-w><')
keymap('n', '<C-w><right>', '15<C-w>>')
keymap('n', '<C-w><up>', '5<C-w>+')
keymap('n', '<C-w><down>', '5<C-w>-')
keymap('n', '<leader>bi', close_all_buffers_but_current, { silent = true, desc = 'Close all buffers except current' })

-- Git
keymap('n', '<leader>gs', ':G<CR>', { silent = true, desc = 'Git status' })
keymap('n', '<leader>gc', ':G commit<CR>', { silent = true, desc = 'Git commit' })
keymap('n', '<leader>gC', ':G commit --amend<CR>', { silent = true, desc = 'Git commit --amend' })
keymap('n', '<leader>gP', ':G push<CR>', { silent = true, desc = 'Git push' })
keymap('n', '<leader>gp', ':G pull<CR>', { silent = true, desc = 'Git pull' })
keymap('n', '<leader>gS', ':G stash<CR>', { silent = true, desc = 'Git stash' })
keymap('n', '<leader>gA', ':G add .<CR>', { silent = true, desc = 'Git add .' })
keymap('n', '<leader>gdd', ':G diff<CR>', { silent = true, desc = 'Git diff' })
keymap('n', '<leader>gf', ':G fetch<CR>', { silent = true, desc = 'Git fetch' })
keymap('n', '<leader>gb', ':G blame<CR>', { silent = true, desc = 'Git blame' })
keymap('n', '<leader>gg', ':Gitsigns preview_hunk<CR>', { silent = true, desc = 'Git preview hunk' })
keymap('n', '<leader>gdv', ':Gvdiffsplit<CR>', { silent = true, desc = 'Git vertical diff split' })
keymap('n', '<leader>gds', ':Gvdiffsplit<CR>', { silent = true, desc = 'Git vertical diff split' })
keymap('n', '<leader>gda', function()
   vim.cmd('G diff HEAD --name-only')
   close_all_buffers_but_current()
end, { silent = true, desc = 'Git diff HEAD --name-only' })
keymap('n', '<leader>gdi', function()
   local current_line_text = vim.fn.getline('.')

   if current_line_text ~= nil then
      close_all_buffers_but_current()
      vim.cmd('new ' .. current_line_text)
      vim.cmd('Gvdiffsplit')
   end
end, { silent = true, desc = 'Git diff current line' })

-- Copilot
keymap('i', '<C-z>', 'copilot#Accept()', { expr = true, silent = true,  desc = 'Copilot complete', noremap = false, replace_keycodes = false})

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
   keymap('n', '<leader>rr', ':!python %<CR>', { silent = true, desc = 'Run python' })

