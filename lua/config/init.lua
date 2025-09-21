vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("data") .. "/undo"

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.softtabstop = 4

vim.opt.smarttab = true
vim.opt.smartcase = true
vim.opt.autoindent = true
vim.opt.smartindent = true

vim.g.editorconfig = true
vim.opt.signcolumn = "yes:1"
vim.opt.inccommand = "split"
vim.opt.smartcase = true
vim.opt.ignorecase = true
vim.opt.guicursor = ""

vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.linebreak = true

if vim.fn.has('nvim-0.11') == 1 then
  vim.opt.completeopt = { "menuone", "noselect", "popup", "noinsert", "fuzzy" }
end

vim.opt.wrap = false
vim.g.mapleader = " "

vim.opt.termguicolors = true

vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"

vim.opt.mouse = ''
vim.opt.cursorline = true

-- Disable suspend
vim.keymap.set("n", "<C-z>", "<Nop>", { noremap = true, silent = true })

vim.g.python3_host_prog = vim.fn.stdpath("config") .. "/.venv/bin/python3"

-- Enable automatic commenting for next line
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  group = vim.api.nvim_create_augroup("Basics", { clear = true }),
  callback = function()
    vim.opt.formatoptions = "cro"
  end,
  desc = "Enable New Line Comment",
})

-- Formatting and break lines
vim.opt.display = vim.o.display .. ",lastline"
vim.opt.list = true
vim.opt.fileformats = { "unix", "dos", "mac" }
vim.opt.fixeol = false
vim.opt.binary = false
vim.opt.endofline = false
vim.opt.eol = false
vim.opt.eof = false

-- Split view
vim.opt.fillchars:append { horiz = "+", vert = "*" }
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.api.nvim_set_hl(0, 'WinSeparator', { fg = "#AAAAAA" })
  end
})

if vim.fn.has("mac") then
  require("config.macos")
end

if vim.fn.has("linux") then
  require("config.linux")
end

if vim.fn.has("win32") then
  require("config.windows")
end

-- Load environment variables
pcall(dofile, vim.fs.joinpath(vim.fn.stdpath("config"), ".env.lua"))

require("config.lazy")
require("config.autocommands")
require("config.usercommands")

require("config.keymaps")
