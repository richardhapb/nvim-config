local utils = require "functions.utils"

local M = {}

local state = {
  buffer = nil,
  conf_filename = nil,
  expanded = false
}

--- Update the config filename into cache
---@param conf_filename string
M.update_conf_filename = function(conf_filename)
  state.conf_filename = conf_filename
end

--- Update the expanded config as a parameter in psql
---@param expanded string
M.update_expanded = function(expanded)
  state.expanded = expanded == 'true'
end


---Return the output of the queries in a buffer
---@param conf_filename? string The name of the file with the database configuration
---@param line1? number The first line of the visual selection
---@param line2? number The last line of the visual selection
M.sql_query = function(conf_filename, line1, line2)
  if not conf_filename or conf_filename == '' then
    if state.conf_filename then
      conf_filename = state.conf_filename
    else
      conf_filename = "sql.json"
    end
  end

  -- Diferents directories for find config files
  local parent_directory = vim.fn.expand("%:p:h")
  local root_directory = vim.fn.getcwd()
  local default_directory = vim.fn.expand("$DEV/config")

  local directories = { parent_directory, root_directory, default_directory }
  local sql_conf = nil

  for _, dir in ipairs(directories) do
    if dir then
      sql_conf = io.open(dir .. "/" .. conf_filename, "r")
      if sql_conf then
        break -- Found it
      end
    end
  end

  if not sql_conf then
    print("Can't find the file " .. conf_filename)
  else
    local db_conf = sql_conf:read("*a")
    sql_conf:close()

    if db_conf then
      local db = vim.fn.json_decode(db_conf)
      local sql_query
      if line1 then
        sql_query = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
        sql_query = table.concat(sql_query, " ")
      else
        sql_query = utils.get_visual_selection()
      end
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
              (state.expanded and ' --expanded ' or '') ..
              ' -p ' ..
              port ..
              ' -U ' ..
              db.user ..
              ' -d ' ..
              db.database ..
              ' -c ' ..
              vim.fn.shellescape(query)
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
        state.buffer = utils.buffer_log(full_output, "split", state.buffer)
      else
        state.buffer = utils.buffer_log({ "No output" }, "vsplit", state.buffer)
      end
    end
  end
end

return M
