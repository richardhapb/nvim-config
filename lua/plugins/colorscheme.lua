local function custom_hl()
   local hl = vim.api.nvim_set_hl

   local visual = { bg = "#555555" }

   -- Theme customization
   hl(0, 'CursorLine', { bg = "#004040" })
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

   hl(0, "NonText", { fg = "#999999" })
   hl(0, "SpecialKey", { fg = "#999999" })
   hl(0, "Whitespace", { fg = "#999999" })

   -- Diff
   hl(0, 'DiffAdd', { bg = "#004000" })
   hl(0, 'DiffChange', { bg = "#000040" })
   hl(0, 'DiffDelete', { bg = "#400000" })

   -- Transparent
   hl(0, 'Normal', { bg = "NONE" })
   hl(0, 'SignColumn', { bg = "NONE" })
   hl(0, 'VertSplit', { bg = "NONE" })
   hl(0, 'FoldColumn', { bg = "NONE" })
   hl(0, 'Folded', { bg = "NONE" })

   -- Visual
   hl(0, 'Visual', visual)
   hl(0, 'VisualNOS', visual)

   -- Diagnostics
   hl(0, 'DiagnosticError', { fg = "#CC0000" })
   hl(0, 'DiagnosticWarn', { fg = "#FFFF00" })
end

return {
   {
      "folke/tokyonight.nvim",
      lazy = false,
      priority = 1000,
      opts = {},
      config = function()
         ---@diagnostic disable-next-line: missing-fields
         require("tokyonight").setup({
            transparent = true,
            styles = {
               sidebars = "transparent",
               floats = "transparent"
            }
         })
         -- vim.cmd([[colorscheme tokyonight-moon]])
         custom_hl()
      end,
   },
   {
      "Shatur/neovim-ayu",
      lazy = false,
      priority = 1000,
      opts = {},
      config = function()
         vim.cmd([[colorscheme ayu-dark]])
         custom_hl()
      end,
   }
}

