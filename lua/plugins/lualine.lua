return {
   'nvim-lualine/lualine.nvim',
   dependencies = { 'nvim-tree/nvim-web-devicons' },
   config = function()
      require('lualine').setup {
         options = {
            theme = 'tokyonight',
            section_separators = { '', '' },
            component_separators = { '', '' },
         },
         sections = {
            lualine_a = { 'mode' },
            lualine_b = { 'branch' },
            lualine_c = { {'filename', color = 'StatusLine' }, 'diff' },
            lualine_x = { 'encoding', 'fileformat', 'filetype' },
            lualine_y = { 'progress' },
            lualine_z = { 'location' },
         },
         inactive_sections = {
            lualine_a = {},
            lualine_b = {{  'branch', color = 'MoreMsg'  }},
            lualine_c = { {'filename', color = 'StatusLineNC' }, 'diff' },
            lualine_x = { { 'location', color = {fg = '#CCCCCC'  }}},
            lualine_y = {},
            lualine_z = {},
         },
         tabline = {},
         extensions = {},
      }
   end,
}
