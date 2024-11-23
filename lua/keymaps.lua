local functions = require("functions")

local keymap = vim.keymap.set

vim.g.mapleader = " "

-- Telescope
keymap(
	"n",
	"<leader>ff",
	"<cmd>Telescope find_files<cr>",
	{ noremap = true, silent = true, desc = "Telescope: Find file" }
)
keymap(
	"n",
	"<leader>fg",
	"<cmd>Telescope live_grep<cr>",
	{ noremap = true, silent = true, desc = "Telescope: Live grep" }
)
keymap("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { noremap = true, silent = true, desc = "Telescope: Buffers" })
keymap(
	"n",
	"<leader>fh",
	"<cmd>Telescope help_tags<cr>",
	{ noremap = true, silent = true, desc = "Telescope: Help Tags" }
)
keymap("n", "<leader>fd", "<cmd>Telescope diagnostics<cr>", { noremap = true, desc = "Show diagnostics" })

-- vim-tmux-navigator
keymap("n", "<C-h>", ":TmuxNavigateLeft<CR>", { noremap = true, silent = true })
keymap("n", "<C-j>", ":TmuxNavigateDown<CR>", { noremap = true, silent = true })
keymap("n", "<C-k>", ":TmuxNavigateUp<CR>", { noremap = true, silent = true })
keymap("n", "<C-l>", ":TmuxNavigateRight<CR>", { noremap = true, silent = true })
keymap("n", "<C-\\>", ":TmuxNavigatePrevious<CR>", { noremap = true, silent = true })

-- Edit
keymap("n", "<leader>cc", "Vy", { noremap = true, desc = "Copy line" })
keymap({ "n", "v", "x" }, "x", '"_x')
keymap("n", "db", 'vb"_d', { noremap = true, desc = "Delete word" })
keymap("n", "dw", 'vw"_d')
keymap("n", "de", 've"_d')
keymap("n", "<leader>cr", function()
	local orig_text = vim.fn.input("Text to replace: ")
	local replace_text = vim.fn.input("Replacing for: ")
	vim.cmd("%s/" .. orig_text .. "/" .. replace_text .. "/g")
end, { noremap = true, desc = "Replace text in current buffer" })
keymap("n", "df", 'v$h"_d')
keymap("n", "<leader>ca", "ggVG", { noremap = true, desc = "Select all" })
keymap("n", "<leader>{", "}V{", { noremap = true, desc = "Select block on top" })
keymap("n", "<leader>}", "{V}", { noremap = true, desc = "Select block on bottom" })

-- Pastify
keymap("v", "<leader>p", ":PastifyAfter<CR>", { noremap = true, silent = true })
keymap("n", "<leader>p", ":PastifyAfter<CR>", { noremap = true, silent = true })
keymap("n", "<leader>P", ":Pastify<CR>", { noremap = true, silent = true })

-- Linter
keymap("n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
keymap(
	"n",
	"<leader>e",
	":lua vim.diagnostic.open_float()<CR>",
	{ noremap = true, silent = true, desc = "Show diagnostics" }
)
keymap(
	"n",
	"<leader>e",
	"<cmd>lua vim.diagnostic.open_float(nil, { focusable = true })<CR>",
	{ noremap = true, silent = true }
)

-- Markdown preview
keymap("n", "<leader>M", "<cmd>MarkdownPreview<cr>", { noremap = true, silent = true, desc = "Preview Markdown" })

-- Functions
keymap("v", "<leader>+", functions.sql_query, { noremap = true, desc = "Evecute a sql script" })

-- Files
keymap("n", "<leader>nn", function()
	local note_name = vim.fn.input("Note name: ")
	vim.cmd("edit " .. vim.fn.expand("$HOME/Documents/notes/inbox/") .. note_name .. ".md")
end, { noremap = true, desc = "Create new generic note" })

-- Explore
keymap("n", "+", ":NvimTreeToggle<CR>", { noremap = true, silent = true, desc = "Toggle tree directories" })
keymap("n", "-", "<CMD>Oil<CR>", { noremap = true, desc = "Open parent directory" })

-- Tabs / split
keymap("n", "te", ":tabedit<cr>", { noremap = true, silent = true })
keymap("n", "ss", ":split<cr><C-w>w", { noremap = true, silent = true })
keymap("n", "sv", ":vsplit<cr><C-w>w", { noremap = true, silent = true })
keymap("n", "<C-w>h", "<C-w><")
keymap("n", "<C-w>j", "<C-w>-")
keymap("n", "<C-w>k", "<C-w>+")
keymap("n", "<C-w>l", "<C-w>>")

-- DEBUG
keymap("n", "<F5>", "<Cmd>lua require'dap'.continue()<CR>", { noremap = true, silent = true, desc = "Execute debug" })
keymap("n", "<F10>", "<Cmd>lua require'dap'.step_over()<CR>", { noremap = true, silent = true, desc = "Step over" })
keymap("n", "<F11>", "<Cmd>lua require'dap'.step_into()<CR>", { noremap = true, silent = true, desc = "Step into" })
keymap("n", "<F12>", "<Cmd>lua require'dap'.step_out()<CR>", { noremap = true, silent = true, desc = "Step out" })
keymap(
	"n",
	"<leader>db",
	"<Cmd>lua require'dap'.toggle_breakpoint()<CR>",
	{ noremap = true, silent = true, desc = "Toggle breakpoint" }
)
keymap(
	"n",
	"<leader>dB",
	"<Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>",
	{ noremap = true, silent = true, desc = "Conditional breakpoint" }
)
keymap("n", "<leader>dr", "<Cmd>lua require'dap'.repl.open()<CR>", { noremap = true, silent = true, desc = "Open" })
keymap("n", "<leader>dl", "<Cmd>lua require'dap'.run_last()<CR>", { noremap = true, silent = true, desc = "Run last" })
keymap(
	"n",
	"<leader>do",
	"<Cmd>lua require('dapui').open()<CR>",
	{ noremap = true, silent = true, desc = "Open panels" }
)
keymap(
	"n",
	"<leader>dc",
	"<Cmd>lua require('dapui').close()<CR>",
	{ noremap = true, silent = true, desc = "Close panels" }
)

-- Jupyter Notebook
keymap("n", "<leader>mi", ":MoltenInit<CR>", { noremap = true, silent = true, desc = "Initialize the plugin" })
keymap(
	"n",
	"<leader>me",
	":MoltenEvaluateOperator<CR>",
	{ noremap = true, silent = true, desc = "run operator selection" }
)
keymap("n", "<leader>ml", ":MoltenEvaluateLine<CR>", { noremap = true, silent = true, desc = "evaluate line" })
keymap("n", "<leader>mr", ":MoltenReevaluateCell<CR>", { noremap = true, silent = true, desc = "re-evaluate cell" })
keymap(
	"v",
	"<leader>mr",
	":<C-u>MoltenEvaluateVisual<CR>gv",
	{ noremap = true, silent = true, desc = "evaluate visual selection" }
)
keymap("n", "<leader>md", ":MoltenDelete<CR>", { noremap = true, silent = true, desc = "molten delete cell" })
keymap("n", "<leader>mh", ":MoltenHideOutput<CR>", { noremap = true, silent = true, desc = "hide output" })
keymap(
	"n",
	"<leader>ms",
	":noautocmd MoltenEnterOutput<CR>",
	{ noremap = true, silent = true, desc = "show/enter output" }
)
keymap(
	"n",
	"<leader>rc",
	"<cmd>lua require('quarto.runner').run_cell()<CR>",
	{ noremap = true, desc = "run cell", silent = true }
)
keymap(
	"n",
	"<leader>ra",
	"<cmd>lua require('quarto.runner').run_above()<CR>",
	{ noremap = true, desc = "run cell and above", silent = true }
)
keymap(
	"n",
	"<leader>rA",
	"<cmd>lua require('quarto.runner').run_all()<CR>",
	{ noremap = true, desc = "run all cells", silent = true }
)
keymap(
	"n",
	"<leader>rl",
	"<cmd>lua require('quarto.runner').run_line()<CR>",
	{ noremap = true, desc = "run line", silent = true }
)
keymap(
	"v",
	"<leader>rp",
	"<cmd>lua require('quarto.runner').run_range()<CR>",
	{ noremap = true, desc = "run visual range", silent = true }
)
keymap(
	"n",
	"<leader>RA",
	"<cmd>lua require('quarto.runner').run_all(true)<CR>",
	{ noremap = true, desc = "run all cells of all languages", silent = true }
)

-- Python
keymap("n", "<leader>rr", ":!python %<CR>", { noremap = true, silent = true, desc = "Run python file" })

-- Terminal
keymap("t", "<Esc>", [[<C-\><C-n>]], { noremap = true, silent = true, desc = "Exit from terminal" })

-- Buffer
keymap("n", "<leader>bw", ":bd<CR>", { noremap = true, silent = true, desc = "Close current buffer" })
