-- Python dict order

local ts_utils = require("nvim-treesitter.ts_utils")

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
   local tabstop = vim.api.nvim_get_option_value("tabstop", { buf = 0 })
   local add_indentation = string.rep(" ", tabstop)

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
         table.insert(equalized, indentation .. add_indentation .. key .. ": " .. spaces .. value)
      else
         if line:match("[%[%{]") then
            table.insert(equalized, line)
         elseif line:match("[%}%]]") then
            table.insert(equalized, indentation .. line)
         elseif line:match(":+") then -- Dict lines
            table.insert(equalized, line)
         else                         -- List Lines
            table.insert(equalized, indentation .. add_indentation .. line)
         end
      end
   end
   return equalized
end

local function format_dict(dict_node, bufnr, indentation, delimiters)
   local pairs = ts_utils.get_named_children(dict_node)
   if #pairs >= 3 then
      local formated = { delimiters.open }
      for _, pair in ipairs(pairs) do
         local pair_text = vim.treesitter.get_node_text(pair, bufnr)
         table.insert(formated, pair_text)
      end
      formated = vim.list_extend(formated, { delimiters.close })
      return equalize_spaces(formated, indentation)
   end
   return nil
end

local function process_buffer(node_name)
   local filetype = vim.api.nvim_get_option_value('filetype', { buf = 0 })
   if filetype ~= "python" then
      print("FormatDicts is only available for Python files")
      return
   end
   local bufnr = vim.api.nvim_get_current_buf()
   local parser = vim.treesitter.get_parser(bufnr, "python")
   local tree = parser:parse()[1]
   local root = tree:root()

   local parsed_query = vim.treesitter.query.get("python", 'custom')

   if not parsed_query then
      print("Query not found")
      return
   end

   local changes = {}

   for id, node in parsed_query:iter_captures(root, bufnr, 0, -1) do
      local capture_name = parsed_query.captures[id]
      if capture_name == node_name then
         local range = { node:range() }
         local indentation = vim.fn.getline(range[1] + 1)

         ---@diagnostic disable-next-line: undefined-field
         indentation = indentation:match("^%s+") or ""

         local delimiters = { open = '{', close = '}' }
         if node_name:match('list') then
            delimiters = { open = '[', close = ']' }
         end

         local formated_dict = format_dict(node, bufnr, indentation, delimiters)
         if formated_dict then
            table.insert(changes, 1, { range = range, new_text = formated_dict })
         end
      end
   end

   for _, change in ipairs(changes) do
      vim.api.nvim_buf_set_text(bufnr, change.range[1], change.range[2], change.range[3], change.range[4],
         change.new_text)

      local last_line = change.range[1] + #change.new_text
      local last_line_text = vim.fn.getline(last_line) or ''

      local next_line = last_line + 1
      local next_line_text = vim.fn.getline(next_line) or ''
      local closes = next_line_text:match('^%s*%)%s*$')

      if closes then
         closes = closes:gsub("%s+", "")
         vim.api.nvim_buf_set_text(bufnr, last_line - 1, 0, next_line - 1, -1, { last_line_text .. closes })
      end
   end
end

vim.api.nvim_create_autocmd('filetype', {
   group = vim.api.nvim_create_augroup('FormatDictGroup', {clear = true}),
   pattern = 'python',
   callback = function()
      vim.api.nvim_buf_create_user_command(0, "FormatDicts", function()
         process_buffer('dict')
         process_buffer('nested_dict')
         process_buffer('nested_list')
      end, {})
   end
})

