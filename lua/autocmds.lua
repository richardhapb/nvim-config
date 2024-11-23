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
