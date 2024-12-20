local M = {}

local ts_utils = require("nvim-treesitter.ts_utils")

M.extract_args_from_func = function(cursor_pos, ts_query)
   local above = cursor_pos == 'above'
   local below = cursor_pos == 'below'

   if not above and not below then
      return nil
   end

   local bufnr = vim.api.nvim_get_current_buf()
   local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
   local parser = vim.treesitter.get_parser(bufnr, filetype)

   if not parser then
      return nil
   end

   local tree = parser:parse()[1]
   local root = tree:root()

   local parsed_query = vim.treesitter.query.parse(filetype, ts_query)

   local captures = {}
   local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

   for id, node in parsed_query:iter_captures(root, bufnr, 0, -1) do
      local capture_name = parsed_query.captures[id]
      if capture_name == "args" then
         local range = { node:range() }

         print("Cursor line: " .. cursor_line)
         print("Range: " .. range[1] .. " " .. range[3])
         -- Prevent extracting args from the function that no is in the cursor line
         if above and range[1] < cursor_line or below and range[3] < cursor_line - 1 then
            goto continue
         end
         local args = ts_utils.get_named_children(node)

         for _, arg in ipairs(args) do
            local arg_text = vim.treesitter.get_node_text(arg, bufnr)
            print("Arg: " .. arg_text)
            table.insert(captures, arg_text)
         end
         break
      end
      ::continue::
   end

   return captures
end

return M
