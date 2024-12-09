
vim.opt.number = true
vim.opt.relativenumber = true

vim.bo.tabstop = 4
vim.bo.shiftwidth = 4
vim.bo.expandtab = true
vim.bo.softtabstop = 4

vim.cmd('syntax on')
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


