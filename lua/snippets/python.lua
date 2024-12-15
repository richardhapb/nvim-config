local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local f = ls.function_node
local t = ls.text_node
local fmt = require 'luasnip.extras.fmt'.fmt
local code = require 'functions.code'

local args_extractor = function()
   local args = code.extract_args_from_func_above_cursor()
   if not args then
      return "No arguments"
   end

   for j, _ in ipairs(args) do
      args[j] = "\t" .. args[j] .. ": ${" .. j + 1 .. ":description}"
   end

   return args
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
      f(args_extractor, {}),
      t("Return"),
      i(2, "Description of return value."),
   })),

   s("p--",
      t('print("\\n--------------------------------------------\\n")')
   ),
})

