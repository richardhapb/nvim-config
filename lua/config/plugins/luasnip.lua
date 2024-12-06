local luasnip = require("luasnip")

local M = {}

function M.setup()
   local keymap = vim.keymap.set

   keymap({ "i", "s" }, "<Tab>", function()
      if luasnip.jumpable(1) then
         luasnip.jump(1)
      else
         vim.api.nvim_put({'\t'}, '', false, true)
      end
   end, { silent = true })

   keymap({ "i", "s" }, "<C-Tab>", function()
      if luasnip.jumpable(-1) then
         luasnip.jump(-1)
      end
   end, { silent = true })

end

return M

