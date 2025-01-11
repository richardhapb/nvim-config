return {
   {
      "folke/tokyonight.nvim",
      lazy = false,
      priority = 1000,
      opts = {},
      config = function()
         require("tokyonight").setup({
            transparent = true,
            styles = {
               sidebars = "transparent",
               floats = "transparent"
            }
         })
         vim.cmd([[colorscheme tokyonight-moon]])

         local hl = vim.api.nvim_set_hl

         -- Theme customization
         local cursor_bg = "#004040"
         hl(0, 'CursorLine', { bg = cursor_bg })
         hl(0, 'CursorLineNr', { bg = cursor_bg})
         hl(0, 'LineNr', { fg = "#FFFFFF" })
         hl(0, 'LineNrAbove', { fg = "#CCCCCC" })
         hl(0, 'LineNrBelow', { fg = "#CCCCCC" })
         hl(0, 'EndOfBuffer', { fg = "#999999" })
         hl(0, 'StatusLine', { bg = "#333333", fg = "#CCCCCC" })
         hl(0, 'StatusLineNC', { bg = "#333333", fg = "#BBBBBB" })
         hl(0, 'DiagnosticUnnecessary', { fg = "#999999" })
         hl(0, 'CopilotSuggestion', { fg = "#FFA500" })
         hl(0, 'Comment', { fg = "#999999" })
         hl(0, 'LspReferenceTarget', { bg = "#111111" })
         hl(0, 'LspReferenceText', { bg = "#111111" })
         hl(0, 'NormalFloat', { bg = "#000000" })
         hl(0, '@markup.raw.markdown_inline', { fg = "#9999FF", bg = nil })

         -- Diff
         hl(0, 'DiffAdd', { bg = "#004000" })
         hl(0, 'DiffChange', { bg = "#000040" })
         hl(0, 'DiffDelete', { bg = "#400000" })
      end
   },
}

