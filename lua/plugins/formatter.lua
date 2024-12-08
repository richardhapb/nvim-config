return {
   'mhartington/formatter.nvim',
   config = function()
      require('formatter').setup({
         log_level = vim.log.levels.WARN,
         filetype = {
            lua = {
               require("formatter.filetypes.lua").stylua,

               function()
                  local util = require('formatter.util')
                  if util.get_current_buf_file_name() == "sepecial.lua" then
                     return nil
                  end

                  return {
                     exe = "stylua",
                     args = {
                        "--search-parent-directories",
                        "--stdin-filepath",
                        util.espcape_path(util.get_current_buf_file_path()),
                        "--",
                        "-"
                     },
                     stdin = true
                  }
               end
            },
            python = {
               function()
                  return {
                     exe = "black",
                     args = { "--fast", "-" },
                     stdin = true
                  }
               end
            }
         }
      })
   end
}
