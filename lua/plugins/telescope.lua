local actions = require('telescope.actions')

return {
  'nvim-telescope/telescope.nvim',
  branch = '0.1.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    "nvim-telescope/telescope-file-browser.nvim",
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }
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
        buffers = {
          theme = "dropdown",
          previewer = false,
          mappings = {
            i = { ["<c-d>"] = actions.delete_buffer },
          },
        }
      },
      defaults = {
        file_ignore_patterns = { "%.git/.*", "node_modules/.*", "build/.*", "dist/.*", "%.DS_Store/.*", "%.cache/.*", "__pycache__/.*", "%.pytest_cache/.*", "%.vscode/.*", "%.idea/.*", "%.clangd/.*", "yarn%.lock$", "package-lock%.json$", ".venv/.*" },
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
          },
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          }
        }
      }
    })
    require("telescope").load_extension "file_browser"
    require("telescope").load_extension("git_worktree")
    require("telescope").load_extension("fzf")
  end,
  keys = {
    {
      '<leader><leader>',
      function() require('telescope.builtin').find_files({ hidden = true }) end,
      desc = 'Telescope find files'
    },
    {
      '<leader>f.',
      function()
        local ok, _ = pcall(require('telescope.builtin').git_files, {})
        if not ok then
          require('telescope.builtin').find_files()
        end
      end,
      desc = 'Telescope find files'
    },

    {
      '<leader>fs',
      function()
        require('telescope.builtin').find_files({
          cwd = vim.fn.stdpath('config'),
          prompt_title = "NVIM config"
        })
      end,
      desc = 'Telescope Nvim config'
    },

    {
      '<leader>fn',
      function()
        require('telescope.builtin').find_files({
          cwd = vim.fn.expand('$NOTES'),
          prompt_title = "Richard's Notes"
        })
      end,
      desc = 'Telescope Richard notes'
    },

    {
      '<leader>fp',
      function()
        require('telescope').extensions.file_browser.file_browser({
          cwd = vim.fn.expand('$DEV'),
          files = false,
          hidden = false,
        })
      end,
      desc = 'Telescope Projects'
    },

    {
      '<leader>fN',
      function()
        require('telescope').extensions.file_browser.file_browser({
          cwd = vim.fn.expand('$NOTES'),
          files = true,
          hidden = false,
        })
      end,
      desc = 'Telescope Richard notes browser'
    },

    {
      '<leader>f-',
      function()
        require('telescope.builtin').find_files({
          cwd = vim.fn.stdpath('data') .. '/lazy',
          prompt_title = "Plugins core files",
        })
      end,
      desc = 'Telescope find plugins core files'
    },

    {
      '<leader>fg',
      function()
        require('telescope.builtin').live_grep({
          file_ignore_patterns = vim.tbl_extend('force', require 'telescope.config'.values.file_ignore_patterns,
            { '^tags$' }),
        })
      end,
      desc = 'Telescope live grep'
    },
    { '<leader>f<space>', function() require('telescope.builtin').buffers() end,                                       desc = 'Tel buffers' },
    { '<leader>fh',       function() require('telescope.builtin').help_tags() end,                                     desc = 'Tel help tags' },
    { '<leader>fc',       function() require('telescope.builtin').commands() end,                                      desc = 'Tel view commands' },
    { '<leader>fk',       function() require('telescope.builtin').keymaps() end,                                       desc = 'Tel normal mode keymaps' },
    { '<leader>fv',       function() require('telescope.builtin').vim_options() end,                                   desc = 'Tel vim options' },
    { '<leader>fq',       function() require 'plugin.telescope-pickers.git'.git_branches_diff() end,                   desc = 'Tel git branches diff' },
    { '<leader>fa',       function() require('telescope.command').load_command("file_browser") end,                    desc = 'Tel file browser' },
    { '<leader>fr',       function() require('telescope.builtin').lsp_references() end,                                desc = 'Tel LSP References' },
    { '<leader>ft',       function() require('telescope.builtin').treesitter() end,                                    desc = 'Tel Treesitter' },
    { '<leader>ff',       function() require('telescope.builtin').builtin() end,                                       desc = 'Tel builtin' },
    { '<leader>f`',       function() require('telescope.builtin').symbols({ sources = { 'emoji' } }) end,              desc = 'Tel emojis' },
    { '<leader>f\\',      function() require('telescope.builtin').symbols({ sources = { 'latex' } }) end,              desc = 'Tel latex' },
    { '<leader>f/',       function() require('telescope.builtin').current_buffer_fuzzy_find() end,                     desc = 'Tel buffer fuzzy finder' },
    { '<leader>fb',       function() require('telescope.builtin').git_branches() end,                                  desc = 'Tel git branches' },
    { '<leader>fd',       function() require 'plugin.telescope-pickers.docker'.docker_containers({ tmux = true }) end, desc = 'Tel docker containers' },
    { '<leader>fw',       function() require('telescope').extensions.git_worktree.git_worktrees() end,                 desc = 'Tel git worktrees' },
    { '<leader>f;',       function() require('telescope.builtin').lsp_dynamic_workspace_symbols() end,                 desc = 'Tel git worktrees' },
    { '<leader>fz',        function() require'telescope.builtin'.grep_string { shorten_path = true, word_match = "-w", only_sort_text = true, search = '' } end, desc = "Tel String Fuzzy Finder"}

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
