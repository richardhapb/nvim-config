local utils = require 'functions.utils'

vim.opt.clipboard:append { "unnamedplus" }

if utils.is_raspberry_pi() then
  --- Use the server to pass the clipboard through SSH
  vim.g.clipboard = {
    name = "ssh-clipboard",
    copy = {
      ['+'] = { 'nc', '-q0', 'localhost', '2224' },
      ['*'] = { 'nc', '-q0', 'localhost', '2224' },
    },
    paste = {
      ['+'] = { 'nc', '-d', 'localhost', '2225' },
      ['*'] = { 'nc', '-d', 'localhost', '2225' },
    },
    cache_enabled = 1
  }
end
