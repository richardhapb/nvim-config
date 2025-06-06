local sql = require('functions.sql')

local M = {}

M.sql_query = sql.sql_query
M.update_conf_filename = sql.update_conf_filename
M.update_expanded = sql.update_expanded

M.setup = function()
  vim.api.nvim_create_autocmd(
    "Filetype",
    {
      pattern = "sql",
      callback = function(callback_args)
        vim.api.nvim_create_user_command('SqlQuery',
          function(args)
            M.sql_query(args.args, args.line1, args.line2)
          end, {
            nargs = '?',
            complete = 'file',
            range = 1
          })

        vim.api.nvim_create_user_command('SqlConfig',
          function(args)
            M.update_conf_filename(args.args)
          end, {
            nargs = 1,
            complete = 'file',
          })

        vim.api.nvim_create_user_command('SqlExpanded',
          function(args)
            M.update_expanded(args.args)
          end, {
            nargs = 1,
            complete = function()
              return { 'true', 'false' }
            end,
          })

        vim.keymap.set('x', '<leader>=', '<ESC><CMD>\'<,\'>SqlQuery<CR>',
          { noremap = true, buffer = callback_args.buf, silent = true, desc = 'Execute SQL query' })
      end
    })
end

return M
