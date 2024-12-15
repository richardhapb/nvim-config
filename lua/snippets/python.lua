require "luasnip.session.snippet_collection".clear_snippets "python"

local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local sn = ls.snippet_node
local d = ls.dynamic_node
local t = ls.text_node
local fmt = require 'luasnip.extras.fmt'.fmt
local code = require 'functions.code'

local args_extractor = function()
   local args = code.extract_args_from_func_above_cursor()
   if not args then
      return sn(nil, t("No args."))
   end

 local nodes = {}
   for idx, arg in ipairs(args) do
      table.insert(nodes, t("\t" .. arg .. ": "))
      table.insert(nodes, i(idx, "Description"))
      if idx < #args then
         table.insert(nodes, t({ "", "" }))
      end
   end

   return sn(nil, nodes)
end

ls.add_snippets("python", {
   s("fdoc", fmt([[
        """
        {}

        Args:
        {}

        Returns:
            {}: {}
        """
        ]], {
      i(1, "Brief summary of the function."),
      d(2, args_extractor, {}),
      t("Return"),
      i(3, "Description of return value."),
   })),

   s("p--",
      t('print("\\n--------------------------------------------\\n")')
   ),
})

