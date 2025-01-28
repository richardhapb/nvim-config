local function relative_from_cwd()
   return vim.fn.expand('%:.')
end

return {
   'nvim-lualine/lualine.nvim',
   dependencies = {
      { 'nvim-tree/nvim-web-devicons' },
      { "ofseed/copilot-status.nvim" }
   },
   config = function()
      require('lualine').setup {
         options = {
            theme = 'ayu',
            section_separators = { '', '' },
            component_separators = { '', '' },
         },
         sections = {
            lualine_a = { { relative_from_cwd, color = 'StatusLine' } },
            lualine_b = { 'branch' },
            lualine_c = { 'diff' },
            lualine_x = {
              'copilot', 'fileformat', 'filetype',
            },
            lualine_y = { 'progress', 'searchcount' },
            lualine_z = { 'location' },
         },
         inactive_sections = {
            lualine_a = { { relative_from_cwd, color = 'StatusLineNC' } },
            lualine_b = {},
            lualine_c = {},
            lualine_x = {},
            lualine_y = {},
            lualine_z = {'diff'},
         },
         tabline = {},
         extensions = {'oil', 'fugitive'},
      }
   end,
}

