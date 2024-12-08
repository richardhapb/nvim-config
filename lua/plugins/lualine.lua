return {
   'nvim-lualine/lualine.nvim',
   dependencies = { 'nvim-tree/nvim-web-devicons' },
   opts = {
      options = {
         globalstatus = true,
      },
      inactive_winbar = { lualine_a = { 'filename' } }
   }
}
