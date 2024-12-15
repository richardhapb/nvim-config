local M = {}

-- Separate by delim
M.split = function(str, delim)
    local result = {}
    for match in (str .. delim):gmatch("(.-)" .. delim) do
        table.insert(result, match)
    end
    return result
end

-- Get the text selected
M.get_visual_selection = function()
    local mode = vim.api.nvim_get_mode().mode

    local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, "<"))
    local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, ">"))

    if not start_row or not start_col or not end_row or not end_col then
        print("No valid selection")
        return ""
    end

    end_col = end_col + 1

    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

    if mode == "v" then
        if #lines == 1 then -- One line
            lines[1] = string.sub(lines[1], start_col + 1, end_col)
        else -- Many lines
            lines[1] = string.sub(lines[1], start_col + 1)
            lines[#lines] = string.sub(lines[#lines], 1, end_col)
        end
    elseif mode == "\22" then -- <C-v> - Block visual mode
        for i = 1, #lines do
            lines[i] = string.sub(lines[i], start_col + 1, end_col + 1)
        end
    end
    return table.concat(lines, "\n")
end


return M

