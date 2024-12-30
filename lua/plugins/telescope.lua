return {
   'nvim-telescope/telescope.nvim',
   branch = '0.1.x',
   dependencies = { 
      'nvim-lua/plenary.nvim',
      "nvim-telescope/telescope-file-browser.nvim",
   },
   config = function()
      require("telescope").setup({
         pickers = {
            find_files = {
               hidden = true
            },
            live_grep = {
               theme = "ivy",
            },
         },
         defaults = {
            file_ignore_patterns = {"%.git/.*", "node_modules/.*", "build/.*", "dist/.*", "%.DS_Store/.*", "%.cache/.*", "__pycache__/.*", "%.pytest_cache/.*", "%.vscode/.*", "%.idea/.*", "%.clangd/.*", "yarn%.lock$", "package-lock%.json$", ".venv/.*"},
            file_sorter = require("telescope.sorters").get_fuzzy_file,
            generic_sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
            initial_mode = "insert",
         },
         extensions = {
               file_browser = {
               depth = 100,
               hidden = true,
               files = false,
               theme = 'dropdown',
               layout_config = {
                  center = {
                     width = 0.55,
                  }
               }
            }
         }
      })
      require("telescope").load_extension "file_browser"
   end,
   keys = {
      { '<leader><leader>', function() require('telescope.builtin').find_files() end, desc = 'Telescope find files' },

      { '<leader>fs', function() require('telescope.builtin').find_files({
            cwd=vim.fn.stdpath('config'),
            prompt_title = "NVIM config" })
         end,
         desc = 'Telescope Nvim config' },

      { '<leader>fn', function() require('telescope.builtin').find_files({
            cwd=vim.fs.joinpath(vim.fn.expand('$HOME'), 'notes'),
            prompt_title = "Richard's Notes" })
         end,
         desc = 'Telescope Richard notes' },

      { '<leader>fp', function() require('telescope').extensions.file_browser.file_browser({
            cwd=vim.fn.expand('$DEV'),
            files=false,
            hidden=false,
         })
         end,
         desc = 'Telescope Projects' },

      { '<leader>fN', function() require('telescope').extensions.file_browser.file_browser({
            cwd=vim.fs.joinpath(vim.fn.expand('$HOME'), 'notes'),
            files=true,
            hidden=false,
         })
         end,
         desc = 'Telescope Richard notes browser' },

      { '<leader>f-', function() require('telescope.builtin').find_files({
         cwd = vim.fn.stdpath('data') .. '/lazy',
         prompt_title = "Plugins core files",
      }) end, desc = 'Telescope find plugins core files' },

      { '<leader>fg', function() require('telescope.builtin').live_grep() end, desc = 'Telescope live grep' },
      { '<leader>fb', function() require('telescope.builtin').buffers() end, desc = 'Telescope buffers' },
      { '<leader>fh', function() require('telescope.builtin').help_tags() end, desc = 'Telescope help tags' },
      { '<leader>fc', function() require('telescope.builtin').commands() end, desc = 'Telescope view commands' },
      { '<leader>fk', function() require('telescope.builtin').keymaps() end, desc = 'Telescope normal mode keymaps' },
      { '<leader>fv', function() require('telescope.builtin').vim_options() end, desc = 'Telescope vim options' },
      { '<leader>fq', function() require 'plugin.telescope-pickers.git'.git_branches_diff() end, desc = 'Telescope git branches diff' },
      { '<leader>fa', function() require('telescope.command').load_command("file_browser") end, desc = 'Telescope file browser' },
      { '<leader>fr', function() require('telescope.builtin').lsp_references() end, desc = 'Telescope LSP References' },
      { '<leader>ft', function() require('telescope.builtin').treesitter() end, desc = 'Telescope Treesitter' },
      { '<leader>ff', function() require('telescope.builtin').builtin() end, desc = 'Telescope builtin' },
      { '<leader>f`', function() require('telescope.builtin').symbols({sources = { 'emoji' }}) end, desc = 'Telescope emojis'},
      { '<leader>f\\', function() require('telescope.builtin').symbols({sources = { 'latex' }}) end, desc = 'Telescope latex'},
      { '<leader>f/', function() require('telescope.builtin').current_buffer_fuzzy_find() end, desc = 'Telescope buffer fuzzy finder'},
      { '<leader>fd', function() require 'plugin.telescope-pickers.docker'.docker_containers() end, desc = 'Telescope docker containers' }

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
