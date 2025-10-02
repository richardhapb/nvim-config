local M = {}

local function custom_hl()
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      vim.api.nvim_set_hl(0, 'WinSeparator', { fg = "#AAAAAA" })
    end
  })

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup("Colorscheme", { clear = true }),
    callback = function()
      local hl = vim.api.nvim_set_hl

      local visual = { bg = "#993333" }

      -- Transparency
      hl(0, 'Normal', { bg = "NONE", fg = "#CCCCCC" })
      hl(0, 'NormalNC', { bg = "NONE", fg = "#CCCCCC" })
      hl(0, 'NormalFloat', { bg = "NONE" })
      hl(0, 'FloatBorder', { bg = 'NONE' })

      -- LSP autocompletion
      hl(0, 'Pmenu', { bg = '#111111' })

      -- Theme customization
      hl(0, 'CursorLine', { bg = "#222222" })
      hl(0, 'LineNr', { fg = "#FFFFFF" })
      hl(0, 'LineNrAbove', { fg = "#CCCCCC" })
      hl(0, 'LineNrBelow', { fg = "#CCCCCC" })
      hl(0, 'EndOfBuffer', { fg = "#999999" })
      hl(0, 'StatusLine', { bg = "#333333", fg = "#CCCCCC" })
      hl(0, 'StatusLineNC', { bg = "#333333", fg = "#BBBBBB" })
      hl(0, 'DiagnosticUnnecessary', { fg = "#999999" })
      hl(0, 'Comment', { fg = "#999999" })
      hl(0, 'LspReferenceTarget', { bg = "#111111" })
      hl(0, 'LspReferenceText', { bg = "#111111" })
      hl(0, '@markup.raw.markdown_inline', { fg = "#9999FF", bg = nil })

      hl(0, "NonText", { fg = "#999999" })
      hl(0, "SpecialKey", { fg = "#999999" })
      hl(0, "Whitespace", { fg = "#999999" })

      -- Diff
      hl(0, 'DiffAdd', { bg = "#004000" })
      hl(0, 'DiffChange', { bg = "#000040" })
      hl(0, 'DiffDelete', { bg = "#400000" })

      -- Transparent
      hl(0, 'SignColumn', { bg = "NONE" })
      hl(0, 'VertSplit', { bg = "NONE" })
      hl(0, 'FoldColumn', { bg = "NONE" })
      hl(0, 'Folded', { bg = "NONE" })

      -- Mode
      hl(0, 'ModeMsg', { bg = "NONE", fg = "#FFCC00" })

      -- Visual
      hl(0, 'Visual', visual)
      hl(0, 'VisualNOS', visual)

      -- Diagnostics
      hl(0, 'DiagnosticError', { fg = "#CC0000", bg = nil })
      hl(0, 'DiagnosticWarn', { fg = "#FFFF00", bg = nil })
      hl(0, 'DiagnosticHint', { fg = "#00FFFF", bg = nil })
      hl(0, 'DiagnosticInfo', { fg = "#AAAAAA", bg = nil })
      hl(0, 'DiagnosticVirtualTextError', { fg = "#CC0000", bg = nil })
      hl(0, 'DiagnosticVirtualTextWarn', { fg = "#FFFF00", bg = nil })
      hl(0, 'DiagnosticVirtualTextHint', { fg = "#00FFFF", bg = nil })
      hl(0, 'DiagnosticVirtualTextInfo', { fg = "#AAAAAA", bg = nil })
    end
  })
end

function M.enable_custom(cs)
  custom_hl()
  vim.cmd("colorscheme " .. cs)
end

return M
