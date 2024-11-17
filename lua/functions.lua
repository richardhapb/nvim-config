
local M = {}

-- Get the text selected
M.get_visual_selection = function()
    local mode = vim.api.nvim_get_mode().mode

    local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, "<"))
    local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, ">"))

    if not start_row or not start_col or not end_row or not end_col then
        print("No valid selection")
    end

    end_col = end_col + 1

    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

    if mode == "v" then
        if #lines == 1 then -- One line
            print(lines)
            lines[1] = string.sub(lines[1], start_col + 1, end_col)
        else -- Many lines
            lines[1] = string.sub(lines[1], start_col + 1)
            lines[#lines] = string.sub(lines[#lines], 1, end_col)
        end
    elseif mode == "\22" then -- <C-v> - Modo visual en bloque
        for i = 1, #lines do
            lines[i] = string.sub(lines[i], start_col + 1, end_col + 1)
        end
    end
    return table.concat(lines, "\n")
end

-- Read json DB config file
M.sql_query = function()
    local directory = vim.fn.expand("%:p:h")
    local sql_conf = io.open(directory .. "/sql.json", "r")
    if sql_conf then
        local db_conf = sql_conf:read("*a")
        sql_conf:close()

        if db_conf then
            local db = vim.fn.json_decode(db_conf)
            local sql_query = M.get_visual_selection()
            if sql_query then
                vim.cmd('FloatermNew --width=0.9 --height=0.7 --autoclose=0 PGPASSWORD="' .. db.password .. '" psql -h ' .. db.host .. ' -U ' .. db.user .. ' -d ' .. db.database .. ' -c ' .. vim.fn.shellescape(sql_query))
            end
        end
    end
end

return M

