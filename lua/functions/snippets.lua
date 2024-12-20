local ls = require("luasnip")
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node local code = require 'functions.code'

local M = {}

M.args_extractor = function(_, _, _, args)
   local cursor_pos = args.cursor_pos
   local query = args.query
   local before_text = args.before_text
   local char_before_old_state = args.char_before_old_state

   if cursor_pos == nil and query == nil then
      return sn(nil, t("No args."))
   end

   if before_text == nil then
      before_text = ""
   end

   if char_before_old_state == nil then
      char_before_old_state = ""
   end

   local args_text = code.extract_args_from_func(cursor_pos, query)
   if #args_text == 0 or args_text == nil then
      return sn(nil, t("No args."))
   end

   local nodes = {}
   for idx, arg in ipairs(args_text) do
      local char = ""
      if idx > 1 then
         char = char_before_old_state
      end
      table.insert(nodes, t(char .. before_text .. arg .. ": "))
      table.insert(nodes, i(idx, "Description"))
      if idx < #args_text then
         table.insert(nodes, t({ "", "" }))
      end
   end

   return sn(nil, nodes)
end
return M
