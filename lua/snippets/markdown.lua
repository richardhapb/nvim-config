local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

ls.add_snippets("markdown", {
	s(
		"code",
		fmt(
			[[
    ```{}
    {}
    ```]],
			{
				i(1, "Language"),
				i(2, "Code"),
			}
		)
	),
})
