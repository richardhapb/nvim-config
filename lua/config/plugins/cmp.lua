local cmp = require("cmp")
local luasnip = require("luasnip")
local cmp_autopairs = require "nvim-autopairs.completion.cmp"

local M = {}

function M.setup()
   cmp.setup({
      snippet = {
         expand = function(args)
            luasnip.lsp_expand(args.body)
         end
      },
      mapping = {
         ["<C-d>"] = cmp.mapping.scroll_docs(-4),
         ["<C-u>"] = cmp.mapping.scroll_docs(4),
         ["<C-e>"] = cmp.mapping.abort(),
         ["<C-n>"] = cmp.mapping.select_next_item(),
         ["<C-p>"] = cmp.mapping.select_prev_item(),
         ["<C-y>"] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Insert,
            select = false
         },
      },
      sources = cmp.config.sources({
         { name = "nvim_lsp" },
         { name = "path" },
         { name = "luasnip" },
         { name = "buffer" },
      }),
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done { map_char = { tex = "" } }),

      cmp.setup.filetype('gitcommit', {
         sources = cmp.config.sources({
            { name = 'git' },
            { name = 'buffer' }
         })
      }),

      cmp.setup.cmdline(':', {
         mapping = cmp.mapping.preset.cmdline(),
         sources = cmp.config.sources({
            {name = 'path'},
            {name = 'cmdline'}
         })
      }),

      cmp.setup.cmdline({ '/', '?' }, {
         mapping = cmp.mapping.preset.cmdline(),
         sources = cmp.config.sources({
            {name = 'buffer'},
         })
      })
   })
end

return M
