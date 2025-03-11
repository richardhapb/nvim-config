require "luasnip.session.snippet_collection".clear_snippets "python"

local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local d = ls.dynamic_node
local t = ls.text_node
local f = ls.function_node

local fmt = require 'luasnip.extras.fmt'.fmt
local snippets = require 'functions.snippets'
local ts_utils = require 'nvim-treesitter.ts_utils'

local query = [[
(function_definition
  parameters: (parameters) @args
    )
]]

local return_type_query = [[
(function_definition
    return_type: (type) @return_type
    )
]]

local function get_return_type()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local bufnr = vim.api.nvim_get_current_buf()

  local parser = vim.treesitter.get_parser(bufnr, "python")

  if not parser then
    return ""
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  local parsed_query = vim.treesitter.query.parse("python", return_type_query)

  for id, node in parsed_query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = parsed_query.captures[id]
    if capture_name == "return_type" then
      local range = { node:range() }

      if range[3] < cursor_line - 1 then
        goto continue
      end

      if range[3] > cursor_line then
        break
      end

      local return_type = ts_utils.get_node_text(node, bufnr)[1]
      if return_type == nil then
        return ""
      end
      return "-> " .. return_type
    end
    ::continue::
  end

  return ""
end

ls.add_snippets("python", {
  s("fdoc", fmt([[
        """
        {}

        Args:
        {}

        Returns:
            Return {}: {}
        """
        ]], {
    i(1, "Brief summary of the function."),
    d(2, snippets.args_extractor, {}, { user_args = { { query = query, cursor_pos = 'below', before_text = "\t" } } }),
    f(get_return_type, {}, {}),
    i(3, "Description of return value."),
  })),

  s("p--",
    t('print("\\n--------------------------------------------\\n")')
  ),
})
