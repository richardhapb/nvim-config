local M = {}

local utils = require "functions.utils"

-- Execute multiple SQL queries and show output in a single Floaterm window
M.sql_query = function()
    -- Diferents directories for find config files
    local parent_directory = vim.fn.expand("%:p:h")
    local root_directory = vim.fn.getcwd()
    local default_directory = vim.fn.expand("$DEV/config")

    local directories = {parent_directory, root_directory, default_directory}
    local sql_conf = nil

    for _, dir in ipairs(directories) do
        if dir then
            sql_conf = io.open(dir .. "/sql.json", "r")
            if sql_conf then
                break -- Found it
            end
        end
    end

    if sql_conf then
        local db_conf = sql_conf:read("*a")
        sql_conf:close()

        if db_conf then
            local db = vim.fn.json_decode(db_conf)
            local sql_query = utils.get_visual_selection()
            local queries = utils.split(sql_query, ";")

            -- Create a temp file for storage data
            local temp_file_path = "/tmp/sql_query_output.txt"
            local temp_file = io.open(temp_file_path, "w")

            if not temp_file then
                print("Error creating temp file")
                return
            end

            for _, query in ipairs(queries) do
                if query ~= "" then
                    -- Replace line break with spaces
                    query = query:gsub("\n", " ")

                    local port = 5432 -- Default port
                    if db.port then
                        port = db.port
                    end
                    --
                    -- Execute and compare
                    local command = 'PGPASSWORD="' .. db.password .. '" psql -h ' .. db.host .. ' -p ' .. port .. ' -U ' .. db.user .. ' -d ' .. db.database .. ' -c ' .. vim.fn.shellescape(query)
                    local output = vim.fn.system(command)

                    -- Write output
                    temp_file:write("Query: " .. query .. "\n")
                    temp_file:write(output .. "\n")
                    temp_file:write("-------------------------------------------------\n")
                end
            end

            if temp_file then
                temp_file:close()
            end

            -- Output in float window
            vim.cmd('FloatermNew --width=0.9 --height=0.7 --autoclose=0 less ' .. temp_file_path)
        end
    else
        print("Can't find the file sql.json.")
    end
end

return M
