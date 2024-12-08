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
         ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
               cmp.select_next_item()
            elseif luasnip.choice_active() then
               luasnip.change_choice()
            else
               fallback()
            end
         end, { "i", "s" }),
         ["<C-Tab>"] = cmp.mapping.select_prev_item(),
         ["<CR>"] = cmp.mapping.confirm {
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
