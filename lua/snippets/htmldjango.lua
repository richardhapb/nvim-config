local ls = require "luasnip"
local s = ls.snippet
local i = ls.insert_node
local fmt = require "luasnip.extras.fmt".fmt

-- HTML snippets
local html_snippets = {
   s("div", fmt('<div>{}</div>', {
      i(1),
   })),
   s("span", fmt('<span>{}</span>', {
      i(1),
   })),
   s("a", fmt('<a href="{}">{}</a>', {
      i(1, "link"),
      i(2, "text"),
   })),
   s("img", fmt('<img src="{}" alt="{}">', {
      i(1, "source"),
      i(2, "description"),
   })),
   s("input", fmt('<input type="{}" name="{}" id="{}" value="{}">', {
      i(1, "type"),
      i(2, "name"),
      i(3, "id"),
      i(4, "value"),
   })),
   s("form", fmt('<form action="{}" method="{}">{}</form>', {
      i(1, "action"),
      i(2, "method"),
      i(3),
   })),
   s("button", fmt('<button type="{}">{}</button>', {
      i(1, "type"),
      i(2, "text"),
   })),
   s("h1", fmt('<h1>{}</h1>', {
      i(1),
   })),
   s("h2", fmt('<h2>{}</h2>', {
      i(1),
   })),
   s("h3", fmt('<h3>{}</h3>', {
      i(1),
   })),
   s("h4", fmt('<h4>{}</h4>', {
      i(1),
   })),
   s("h5", fmt('<h5>{}</h5>', {
      i(1),
   })),
   s("h6", fmt('<h6>{}</h6>', {
      i(1),
   })),
   s("p", fmt('<p>{}</p>', {
      i(1),
   })),
   s("strong", fmt('<strong>{}</strong>', {
      i(1),
   })),
   s("em", fmt('<em>{}</em>', {
      i(1),
   })),
   s("pre", fmt('<pre>{}</pre>', {
      i(1),
   })),
   s("code", fmt('<code>{}</code>', {
      i(1),
   })),
   s("ul", fmt('<ul>{}</ul>', {
      i(1),
   })),
   s("ol", fmt('<ol>{}</ol>', {
      i(1),
   })),
   s("li", fmt('<li>{}</li>', {
      i(1),
   })),
   s("table", fmt('<table>{}</table>', {
      i(1),
   })),
   s("tr", fmt('<tr>{}</tr>', {
      i(1),
   })),
   s("th", fmt('<th>{}</th>', {
      i(1),
   })),
   s("td", fmt('<td>{}</td>', {
      i(1),
   })),
   s("html", fmt([[
   <!DOCTYPE html>
   <html lang="en">
   <head>
      <meta charset="UTF-8">
      <meta http-equiv="X-UA-Compatible" content="IE=edge">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>{}</title>
   </head>
   <body>
      {}
   </body>
   </html>
   ]], {
      i(1, "title"),
      i(2),
   })),
}

ls.add_snippets("html", html_snippets)

-- HTML-Django snippets
local htmldjango_snippets = vim.tbl_extend("force", html_snippets, {
   s("if", fmt([[
   {{% if {} %}}
      {}
   {{% endif %}}
   ]], {
      i(1),
      i(2),
   })),
   s("ife", fmt([[
   {{% if {} %}}
      {}
   {{% else %}}
   {{% endif %}}
   ]], {
      i(1),
      i(2),
   })),
   s("ifei", fmt([[
   {{% if {} %}}
      {}
   {{% elif {} %}}
   {{% else %}}
   {{% endif %}}
   ]], {
      i(1),
      i(2),
      i(3),
   })),
   s("for", fmt([[
   {{% for {} in {} %}}
      {}
   {{% endfor %}}
   ]], {
      i(1, "item"),
      i(2, "collection"),
      i(3),
   })),
   s("block", fmt([[
   {{% block {} %}}
      {}
   {{% endblock %}}
   ]], {
      i(1, "name"),
      i(2),
   })),
   s("extends", fmt([[
   {{% extends '{}' %}}
   ]], {
      i(1, "base.html"),
   })),
   s("include", fmt([[
   {{% include '{}' %}}
   ]], {
      i(1, "partial.html"),
   })),
   s("comment", fmt([[
   {{# {} #}}
   ]], {
      i(1, "comment text"),
   })),
   s("trans", fmt([[
   {{% trans '{}' %}}
   {}
   ]], {
      i(1, "text to translate"),
      i(2),
   })),
})

ls.add_snippets("htmldjango", htmldjango_snippets)
