local sql = require('functions.sql')

local M = {}

M.sql_query = sql.sql_query

M.setup = function()
  vim.api.nvim_create_autocmd(
    "Filetype",
    {
      pattern = "sql",
      callback = function()
        vim.api.nvim_create_user_command('SqlQuery',
          function(args)
            M.sql_query(args.args, args.line1, args.line2)
          end, {
            nargs = '?',
            complete = 'file',
            range = 1
          })

        vim.keymap.set('x', '<leader>=', '<ESC><CMD>\'<,\'>SqlQuery<CR>',
          { noremap = true, silent = true, desc = 'Execute SQL query' })
      end
    })
end

return M
