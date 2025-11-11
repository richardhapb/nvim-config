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
  vim.o.shortmess = vim.o.shortmess .. "c"
  vim.o.pumblend = 0 -- crisp
end

vim.opt.wrap = false
vim.g.mapleader = " "

vim.opt.termguicolors = true

vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"

vim.opt.mouse = ''
vim.opt.cursorline = true

vim.g.python3_host_prog = vim.fn.stdpath("config") .. "/.venv/bin/python3"

local basic = vim.api.nvim_create_augroup("Basics", { clear = true })
-- Enable automatic commenting for next line
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  group = basic,
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

-- fuzzy is not in the docs recommendation, but worth to add to
vim.o.wildoptions = 'pum,fuzzy'
-- lastused is specially useful when use cmds like `:b` to move between open buffers
vim.o.wildmode = 'noselect:lastused,full'

require('vim._extui').enable({}) -- this is a must even if you don't use anything else of this setup

-- Fuzzy finder
local files_list
---@param cmdarg string
function FindFunc(cmdarg, _)
  if not files_list then
    local cmd = { 'fd', '--type', 'file', '--relative-path', '--color', 'never', '--hidden', '.'}
    local files = vim.system(cmd, { text = true }):wait()
    if not files.stdout then
      return {}
    end
    files_list = vim.split(vim.trim(files.stdout), '\n')
  end
  return vim.fn.matchfuzzy(files_list, cmdarg)
end

vim.o.findfunc = 'v:lua.FindFunc'

vim.api.nvim_create_autocmd({ 'CmdlineLeave' }, {
  callback = function()
    files_list = nil
  end,
  group = basic,
})
