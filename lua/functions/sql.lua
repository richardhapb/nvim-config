local utils = require "functions.utils"

local M = {}

-- Execute multiple SQL queries and show output in a single Floaterm window
M.sql_query = function()
   -- Diferents directories for find config files
   local parent_directory = vim.fn.expand("%:p:h")
   local root_directory = vim.fn.getcwd()
   local default_directory = vim.fn.expand("$DEV/config")

   local directories = { parent_directory, root_directory, default_directory }
   local sql_conf = nil

   for _, dir in ipairs(directories) do
      if dir then
         sql_conf = io.open(dir .. "/sql.json", "r")
         if sql_conf then
            break -- Found it
         end
      end
   end

   if not sql_conf then
      print("Can't find the file sql.json.")
   else
      local db_conf = sql_conf:read("*a")
      sql_conf:close()

      if db_conf then
         local db = vim.fn.json_decode(db_conf)
         local sql_query = utils.get_visual_selection()
         local queries = vim.split(sql_query, ";")

         local full_output = {}

         for _, query in ipairs(queries) do
            if query:match("%S") then
               -- Replace line break with spaces
               query = query:gsub("%s+", " ")

               local port = 5432 -- Default port
               if db.port then
                  port = db.port
               end
               --
               -- Execute and compare
               local command = 'PGPASSWORD="' ..
                   db.password ..
                   '" psql -h ' ..
                   db.host ..
                   ' -p ' .. port .. ' -U ' .. db.user .. ' -d ' .. db.database .. ' -c ' .. vim.fn.shellescape(query)
               local output = vim.fn.systemlist(command)

               if output then
                  table.insert(full_output, "Query: " .. query)
                  table.insert(full_output, "")
                  vim.list_extend(full_output, output)
                  table.insert(full_output, "")
                  table.insert(full_output, string.rep('-', 80))
                  table.insert(full_output, "")
               end
            end
         end

         if full_output then
            utils.buffer_log(full_output, "split")
         else
            utils.buffer_log({ "No output" }, "vsplit")
         end
      end
   end
end

return M

