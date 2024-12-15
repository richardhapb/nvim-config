local M = {}

M.extract_func_header_above_cursor = function()
   local current_line = vim.fn.line('.')
   local function_header = ""

	for i = current_line -1, 1, -1 do
     local temp_line = vim.fn.getline(i)
     if #temp_line:gsub("%s+", "") == 0 and i ~= current_line then
        break
     end
     function_header = temp_line .. function_header
   end

   return function_header
end

M.extract_func_arguments = function(function_header, keyword)
   if not keyword then
      keyword = ""
   end

   local args = function_header:match(keyword .. ".+%b()")
   if args then
      args = args:match("%b()")
      args = args:sub(2, -2)
      args = args:gsub("%s+", "")
      args = vim.split(args, ",")
   end
   return args
end

M.extract_args_from_func_above_cursor = function()
   local function_header = M.extract_func_header_above_cursor()
   if not function_header then
      return {}
   end

   local args = M.extract_func_arguments(function_header)

   if not args then
      return {}
   end
   return args
end

local args = M.extract_args_from_func_above_cursor()

for _, a in ipairs(args) do
   print(a)
end

return M
