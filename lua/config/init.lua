
vim.opt.number = true
vim.opt.relativenumber = true

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

require("config.keymaps")

require("config.lazy")
