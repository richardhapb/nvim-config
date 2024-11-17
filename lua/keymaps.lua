local keymap = vim.keymap.set

vim.g.mapleader = ' '

-- Atajos de teclado para Telescope
keymap('n', '<leader>ff', "<cmd>Telescope find_files<cr>", { noremap = true, silent = true, desc="Telescope: Find file" })
keymap('n', '<leader>fg', "<cmd>Telescope live_grep<cr>", { noremap = true, silent = true , desc="Telescope: Live grep"})
keymap('n', '<leader>fb', "<cmd>Telescope buffers<cr>", { noremap = true, silent = true, desc="Telescope: Buffers" })
keymap('n', '<leader>fh', "<cmd>Telescope help_tags<cr>", { noremap = true, silent = true, desc="Telescope: Help Tags" })

-- Edit
keymap('n', '<leader>c', "Vy", {desc = "Copy line"})
keymap('n', 'x', '"_x')
keymap('n', 'db', 'vb"_d', {desc = "Delete word"})
keymap('n', 'z', '$a')
keymap('n', 'dw', 'vw"_d')
keymap('n', 'de', 've"_d')
keymap('n', '<leader>p', function()
    local orig_text = vim.fn.input("Text to replace: ")
    local replace_text = vim.fn.input("Replacing for: ")
    vim.cmd('%s/' .. orig_text .. '/' .. replace_text .. '/g')
end)
keymap('n', 'df', 'v$h"_d')

-- Files
keymap('n', '<leader>nn', function()
    local note_name = vim.fn.input("Note name: ")
    vim.cmd("edit " .. vim.fn.expand("$HOME/Documents/notes/inbox/") .. note_name .. ".md")
end, { desc = "Create new generic note" })

-- Explore
keymap('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true, desc="Toggle tree directories"})
keymap("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

-- Tabs / split
keymap('n', 'te', ':tabedit<cr>', {silent=true})
keymap('n', 'ss', ':split<cr><C-w>w', { silent=true })
keymap('n', 'sv', ':vsplit<cr><C-w>w', {silent=true})
keymap('n', '<C-w>h', '<C-w><')
keymap('n', '<C-w>j', '<C-w>-')
keymap('n', '<C-w>k', '<C-w>+')
keymap('n', '<C-w>l', '<C-w>>')

-- DEBUG
keymap("n", "<F5>", "<Cmd>lua require'dap'.continue()<CR>", { noremap = true, silent = true, desc="Execute debug" })
keymap("n", "<F10>", "<Cmd>lua require'dap'.step_over()<CR>", { noremap = true, silent = true, desc="Step over" })
keymap("n", "<F11>", "<Cmd>lua require'dap'.step_into()<CR>", { noremap = true, silent = true, desc="Step into" })
keymap("n", "<F12>", "<Cmd>lua require'dap'.step_out()<CR>", { noremap = true, silent = true, desc="Step out" })
keymap("n", "<leader>db", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", { noremap = true, silent = true, desc = "Toggle breakpoint" })
keymap("n", "<leader>dB", "<Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", { noremap = true, silent = true, desc="Conditional breakpoint" })
keymap("n", "<leader>dr", "<Cmd>lua require'dap'.repl.open()<CR>", { noremap = true, silent = true, desc="Open" })
keymap("n", "<leader>dl", "<Cmd>lua require'dap'.run_last()<CR>", { noremap = true, silent = true, desc="Run last" })
keymap("n", "<leader>do", "<Cmd>lua require('dapui').open()<CR>", { noremap = true, silent = true, desc="Open panels"})
keymap("n", "<leader>dc", "<Cmd>lua require('dapui').close()<CR>", { noremap = true, silent = true, desc="Close panels"})

-- Jupyter Notebook
keymap("n", "<leader>mi", ":MoltenInit<CR>", { silent = true, desc = "Initialize the plugin" })
keymap("n", "<leader>me", ":MoltenEvaluateOperator<CR>", { silent = true, desc = "run operator selection" })
keymap("n", "<leader>ml", ":MoltenEvaluateLine<CR>", { silent = true, desc = "evaluate line" })
keymap("n", "<leader>mr", ":MoltenReevaluateCell<CR>", { silent = true, desc = "re-evaluate cell" })
keymap("v", "<leader>mr", ":<C-u>MoltenEvaluateVisual<CR>gv", { silent = true, desc = "evaluate visual selection" })
keymap("n", "<leader>md", ":MoltenDelete<CR>", { silent = true, desc = "molten delete cell" })
keymap("n", "<leader>mh", ":MoltenHideOutput<CR>", { silent = true, desc = "hide output" })
keymap("n", "<leader>ms", ":noautocmd MoltenEnterOutput<CR>", { silent = true, desc = "show/enter output" })
keymap("n", "<leader>rc", "<cmd>lua require('quarto.runner').run_cell()<CR>", { desc = "run cell", silent = true })
keymap("n", "<leader>ra", "<cmd>lua require('quarto.runner').run_above()<CR>", { desc = "run cell and above", silent = true })
keymap("n", "<leader>rA", "<cmd>lua require('quarto.runner').run_all()<CR>", { desc = "run all cells", silent = true })
keymap("n", "<leader>rl", "<cmd>lua require('quarto.runner').run_line()<CR>", { desc = "run line", silent = true })
keymap("v", "<leader>rp", "<cmd>lua require('quarto.runner').run_range()<CR>", { desc = "run visual range", silent = true })
keymap("n", "<leader>RA", "<cmd>lua require('quarto.runner').run_all(true)<CR>", { desc = "run all cells of all languages", silent = true })

-- Python
keymap('n', '<leader>rr', ':!python %<CR>', { noremap = true, silent = true, desc="Run python file" })

-- Terminal
keymap('t', '<Esc>', [[<C-\><C-n>]], { noremap = true, silent = true, desc="Exit from terminal" })

-- Buffer
keymap('n', '<leader>bw', ':bd<CR>', { noremap = true, silent = true })

