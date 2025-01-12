return {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
   config = function()

      local highlight = {
          "RainbowRed",
          "RainbowYellow",
          "RainbowBlue",
          "RainbowOrange",
          "RainbowGreen",
          "RainbowViolet",
          "RainbowCyan",
      }

      local ibl = require 'ibl'
      local hooks = require 'ibl.hooks'

      local color = "#444444"

      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
         for _, hl in ipairs(highlight) do
            vim.api.nvim_set_hl(0, hl, { fg = color })
         end
      end)

      ibl.setup {
         indent = {
            highlight = highlight,
         },
      }


end
}

