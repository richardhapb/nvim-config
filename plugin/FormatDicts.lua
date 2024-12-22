-- Python dict order

local ts_utils = require("nvim-treesitter.ts_utils")

-- Query Tree-sitter
local query = [[
  (expression_statement
    (assignment
      right: (dictionary) @dict))

  (call
    arguments: (argument_list
                 (keyword_argument
                   value: (dictionary) @dict)))

  (call
    arguments: (argument_list
                 (dictionary) @dict))

(dictionary
  (pair
value: (dictionary) @nested_dict))

(dictionary
  (pair
value: (list) @nested_list))
]]

local function max_key_length(lines)
   local max_length = 0
   for _, line in ipairs(lines) do
      local key, _ = line:match("^(.-):%s*(.+)$")
      if key then
         local length = string.len(key)
         if length > max_length then
            max_length = length
         end
      end
   end
   return max_length
end

local function equalize_spaces(lines, indentation)
   local max_length = max_key_length(lines)
   local equalized = {}
   for i, line in ipairs(lines) do
      line = line:gsub("%s+", " ")
      local key, value = line:match("^(.-):%s*(.+)$")
      local length = 0
      if key then
         length = string.len(key)
      end
      local spaces = string.rep(" ", max_length - length)
      if key and value then
         if i < #lines - 1 then
            value = value .. ","
         end
         table.insert(equalized, indentation .. key .. ": " .. spaces .. value)
      else
         if line:match("[[{]") then
            table.insert(equalized, line)
         elseif line:match("[}]]") then
            if indentation:len() >= 4 then
               table.insert(equalized, indentation:sub(5) .. line)
            else
               table.insert(equalized, line)
            end
         elseif line:match(":+") then -- Dict lines
            table.insert(equalized, line)
         else -- List Lines
            table.insert(equalized, indentation .. line)
         end
      end
   end
   return equalized
end

local function format_dict(dict_node, bufnr, indentation, delimiters)
   local pairs = ts_utils.get_named_children(dict_node)
   if #pairs >= 3 then
      local formatted = { delimiters.open }
      for _, pair in ipairs(pairs) do
         local pair_text = vim.treesitter.get_node_text(pair, bufnr)
         table.insert(formatted, pair_text)
      end
      formatted = vim.list_extend(formatted, { delimiters.close })
      return equalize_spaces(formatted, indentation)
   end
   return nil
end

local function process_buffer(node_name)
   local filetype = vim.api.nvim_buf_get_option(0, "filetype")
   if filetype ~= "python" then
      print("FormatDicts is only available for Python files")
      return
   end
   local bufnr = vim.api.nvim_get_current_buf()
   local parser = vim.treesitter.get_parser(bufnr, "python")
   local tree = parser:parse()[1]
   local root = tree:root()

   local parsed_query = vim.treesitter.query.parse("python", query)

   local changes = {}

   for id, node in parsed_query:iter_captures(root, bufnr, 0, -1) do
      local capture_name = parsed_query.captures[id]
      if capture_name == node_name then
         local range = { node:range() }
         local current_indentation = vim.api.nvim_buf_get_lines(bufnr, range[1], range[1] + 1, false)[1]:match("^%s*") or ""

         local delimiters = {open='{', close='}'}
         if node_name:match('list') then
            delimiters = {open='[', close=']'}
         end

         local indentation = string.rep(" ", current_indentation:len() + 4)
         local formatted_dict = format_dict(node, bufnr, indentation, delimiters)
         if formatted_dict then
            table.insert(changes, 1, { range = range, new_text = formatted_dict })
         end
      end
   end

   for _, change in ipairs(changes) do
      vim.api.nvim_buf_set_text(bufnr, change.range[1], change.range[2], change.range[3], change.range[4],
         change.new_text)
   end
end

vim.api.nvim_create_user_command("FormatDicts", function()
   process_buffer('dict')
   process_buffer('nested_dict')
   process_buffer('nested_list')
end, {})
