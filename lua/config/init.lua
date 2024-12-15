
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

vim.opt.mouse = ''

vim.api.nvim_set_hl(0, 'Normal', {bg=nil})
vim.api.nvim_set_hl(0, 'Normal', {ctermbg=nil})
vim.api.nvim_set_hl(0, 'NonText', {bg=nil})
vim.api.nvim_set_hl(0, 'NonText', {ctermbg=nil})

-- Disable suspend
vim.keymap.set("n", "<C-z>", "<Nop>", { noremap = true, silent = true })

-- Disable automatic commenting for next line
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt.formatoptions:remove { "c", "r", "o" }
  end,
  desc = "Disable New Line Comment",
})

-- Split view
vim.opt.fillchars:append {horiz = "+", vert = "*"}
vim.api.nvim_create_autocmd("VimEnter",{
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

require("config.autocommands")

require("config.lazy")
require("config.keymaps")


