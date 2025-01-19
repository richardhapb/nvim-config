local sql = require('functions.sql')

local M = {}

M.sql_query = sql.sql_query

M.setup = function()
   vim.api.nvim_create_autocmd(
      "Filetype",
      {
         pattern = "sql",
         callback = function()
            vim.api.nvim_create_user_command('SqlQuery', sql.sql_query, {
               nargs = 0,
            })

            vim.keymap.set('x', '<leader>=', '<CMD>SqlQuery<CR>',
               { noremap = true, silent = true, desc = 'Execute SQL query' })
         end
      })
end

M.setup()

return M

