return {
   'nvim-telescope/telescope.nvim',
   branch = '0.1.x',
   dependencies = { 'nvim-lua/plenary.nvim', "nvim-telescope/telescope-file-browser.nvim", },
   config = function()
      require("telescope").setup({})
      require("telescope").load_extension "file_browser"
   end,
   keys = {
      { '<leader><leader>', function() require('telescope.builtin').find_files() end, desc = 'Telescope find files' },
      { '<leader>fg', function() require('telescope.builtin').live_grep() end, desc = 'Telescope live grep' },
      { '<leader>fb', function() require('telescope.builtin').buffers() end, desc = 'Telescope buffers' },
      { '<leader>fh', function() require('telescope.builtin').help_tags() end, desc = 'Telescope help tags' },
      { '<leader>fc', function() require('telescope.builtin').commands() end, desc = 'Telescope view commands' },
      { '<leader>fk', function() require('telescope.builtin').keymaps() end, desc = 'Telescope normal mode keymaps' },
      { '<leader>fv', function() require('telescope.builtin').vim_options() end, desc = 'Telescope vim options' },
      { '<leader>fr', function() require('telescope.builtin').registers() end, desc = 'Telescope registers' },
      { '<leader>fq', function() require('telescope.builtin').git_files({ show_untracked = true }) end, desc = 'Telescope git files' },
      { '<leader>fa', function() require('telescope.command').load_command("file_browser") end, desc = 'Telescope file browser' }
   },
   opts = {
		extensions = {
         theme = "ivy",
         hijack_netrw = true,
         mappings = {
            ["i"] = {},
            ["n"] = {}
         }
      }

   }
}
