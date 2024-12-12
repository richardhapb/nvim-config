
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.softtabstop = 4

vim.opt.smarttab = true
vim.opt.smartcase = true

vim.g.editorconfig = true

vim.opt.wrap = false
vim.g.mapleader = " "

vim.opt.termguicolors = true
vim.cmd [[
  highlight Normal guibg=none
  highlight NonText guibg=none
  highlight Normal ctermbg=none
  highlight NonText ctermbg=none
]]

if vim.fn.has("mac") then
   require("config.macos")
end

if vim.fn.has("linux") then
   require("config.linux")
end

if vim.fn.has("win32") then
   require("config.windows")
end

require("config.autocommands")

require("config.lazy")
require("config.keymaps")


