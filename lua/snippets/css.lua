local ls = require("luasnip")
local i = ls.insert_node
local s = ls.snippet
local fmt = require("luasnip.extras.fmt").fmt

ls.add_snippets("css", {
   s("css", fmt([[
   {} {{
       {}: {};
       {}
   }}
   ]], {
      i(1, "selector"),
      i(2, "property"),
      i(3, "value"),
      i(4, "")
   })),
   s("prop", fmt([[
   {}: {};
   {}
   ]], {
      i(1, "property"),
      i(2, "value"),
      i(3, "")
   }))
})
