require "luasnip.session.snippet_collection".clear_snippets "javascript"

local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local d = ls.dynamic_node
local fmt = require 'luasnip.extras.fmt'.fmt
local snippets = require 'functions.snippets'

local query = [[
(function_expression 
    parameters: (formal_parameters) @args)

(arrow_function
  parameters: (formal_parameters) @args)

(function_declaration
  parameters: (formal_parameters) @args)
   ]]

ls.add_snippets("javascript", {
   s("fdoc", fmt([[
        /**
         * {}
         * 
         {}
         * @returns {}: {}
         */
         ]], {
      i(1, "Brief summary of the function."),
      d(2, snippets.args_extractor, {}, { user_args = {{ cursor_pos = "above", query = query, before_text = "* @param ", char_before_old_state = " " }} }),
      i(3, "Return"),
      i(4, "Description of return value."),
   })),

   s("p--",
      t('console.log("\\n--------------------------------------------\\n")')
   ),
})


