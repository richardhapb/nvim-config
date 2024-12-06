require("config.lazy")

vim.opt.number = true
vim.opt.relativenumber = true

vim.cmd('syntax on')
vim.opt.termguicolors = true

vim.opt.wrap = false

vim.cmd [[
  highlight Normal guibg=none
  highlight NonText guibg=none
  highlight Normal ctermbg=none
  highlight NonText ctermbg=none
]]

