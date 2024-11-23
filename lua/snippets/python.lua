local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local f = ls.function_node
local t = ls.text_node
local fmt = require("luasnip.extras.fmt").fmt

-- Función para detectar y formatear los parámetros
local function get_function_params(args, parent)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    if cursor_line == 1 then
        return { ":param None: No parameters." }
    end

    local line = vim.api.nvim_buf_get_lines(0, cursor_line - 2, cursor_line - 1, false)[1]
    if not line or line:match("^%s*$") then
        return { ":param None: No parameters." }
    end

    local params = line:match("def%s+.-%((.-)%)")
    if not params or params == "" then
        return { ":param None: No parameters." }
    end

    local param_list = vim.split(params, ",", true)
    local formatted_params = {}
    for _, param in ipairs(param_list) do
        param = vim.trim(param)
        if param ~= "" then
            table.insert(formatted_params, string.format(":param %s: {}", param))
        end
    end

    if #formatted_params == 0 then
        return { ":param None: No parameters." }
    end

    return formatted_params
end

-- Agregar el snippet para Python
ls.add_snippets("python", {
    s("doc", fmt([[
        """
        {}
        Args:
        {}
        Returns:
            {}: {}
        """
        ]], {
        i(1, "Brief summary of the function."),
        f(get_function_params, {}), -- Corrige el retorno como tabla
        i(2, "Return type"),
        i(3, "Description of return value."),
    })),

    s("p--",
    t('print("\\n--------------------------------------------\\n")')
    )
}
)

ls.add_snippets("ipynb", {
    s("ipynb", {
        t({
            '{',
            ' "cells": [',
            '  {',
            '   "cell_type": "code",',
            '   "execution_count": null,',
            '   "metadata": {},',
            '   "outputs": [],',
            '   "source": []',
            '  }',
            ' ],',
            ' "metadata": {',
            '  "kernelspec": {',
            '   "display_name": "Python 3",',
            '   "language": "python",',
            '   "name": "python3"',
            '  },',
            '  "language_info": {',
            '   "codemirror_mode": {',
            '    "name": "ipython",',
            '    "version": 3',
            '   },',
            '   "file_extension": ".py",',
            '   "mimetype": "text/x-python",',
            '   "name": "python",',
            '   "nbconvert_exporter": "python",',
            '   "pygments_lexer": "ipython3",',
            '   "version": "3.9.7"',
            '  }',
            ' },',
            ' "nbformat": 4,',
            ' "nbformat_minor": 5',
            '}'
        }),
    }),
})
