-- MARKDOWN
vim.api.nvim_create_autocmd("BufWinEnter", {
	pattern = { "*.md" },
	callback = function()
		vim.opt.colorcolumn = "80"
		vim.opt.textwidth = 0
		vim.opt.wrap = true
		vim.opt.linebreak = true
	end,
})

vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
	pattern = { "*.md" },
	callback = function()
		vim.opt.colorcolumn = "120"
		vim.opt.textwidth = 120
	end,
})

-- Linter
local lint = require("lint")

vim.api.nvim_create_augroup("LintAutogroup", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = "*.py",
	callback = function()
		lint.try_lint()
	end,
	group = "LintAutogroup",
})

vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = "*.js",
	callback = function()
		lint.try_lint()
	end,
	group = "LintAutogroup",
})

-- PYTHON
vim.api.nvim_create_autocmd("BufNewFile", {
	pattern = "*.ipynb",
	callback = function()
		local content = [[
{
 "cells": [],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python",
   "version": "3.9.7"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 5
}
]]
		vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(content, "\n"))
	end,
})
